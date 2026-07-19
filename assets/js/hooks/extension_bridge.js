// Browser-extension identity bridge for Qadabra-origin pages.
//
// Authed page  → mint Phoenix.Token into extension vault
// Unauthed page → redeem vault token via /auth/extension_exchange
//                 then reuse AuthFinalize-style LiveSocket reconnect
//
// Publisher pages never call this; only Qadabra hosts + widget iframes.

const PROBE_TIMEOUT_MS = 250

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
}

function extensionRuntime() {
  return typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.sendMessage
    ? chrome.runtime
    : null
}

function extensionIds() {
  const meta = document
    .querySelector("meta[name='qadabra-extension-ids']")
    ?.getAttribute("content")
  if (!meta) return []
  return meta
    .split(",")
    .map((s) => s.trim())
    .filter((id) => id && id !== "DEV_EXTENSION_ID_PLACEHOLDER")
}

function sendToExtension(message) {
  const runtime = extensionRuntime()
  const ids = extensionIds()
  if (!runtime || ids.length === 0) return Promise.resolve(null)

  return new Promise((resolve) => {
    let remaining = ids.length
    let settled = false

    const finish = (value) => {
      if (settled) return
      settled = true
      resolve(value)
    }

    const timer = setTimeout(() => finish(null), PROBE_TIMEOUT_MS)

    ids.forEach((id) => {
      try {
        runtime.sendMessage(id, message, (response) => {
          remaining -= 1
          if (settled) return
          if (runtime.lastError) {
            if (remaining <= 0) {
              clearTimeout(timer)
              finish(null)
            }
            return
          }
          clearTimeout(timer)
          finish(response || null)
        })
      } catch (_err) {
        remaining -= 1
        if (remaining <= 0) {
          clearTimeout(timer)
          finish(null)
        }
      }
    })
  })
}

async function fetchJson(url, options = {}) {
  const res = await fetch(url, {
    credentials: "same-origin",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "x-csrf-token": csrfToken(),
      ...(options.headers || {})
    },
    ...options
  })
  return res
}

function reconnectLiveSocket() {
  const socket = window.liveSocket
  if (!socket) {
    window.location.reload()
    return
  }

  const timeout = setTimeout(() => window.location.reload(), 5000)
  const rawSocket = typeof socket.socket === "function" ? socket.socket() : socket.socket
  if (rawSocket && typeof rawSocket.onOpen === "function") {
    rawSocket.onOpen(() => clearTimeout(timeout))
  }
  socket.disconnect()
  socket.connect()
}

export async function probeExtension() {
  const res = await sendToExtension({ type: "qadabra:auth:probe" })
  return {
    present: !!res?.ok,
    authed: !!res?.authed
  }
}

export async function mintTokenIntoExtension() {
  const deviceRes = await sendToExtension({ type: "qadabra:auth:get-device-id" })
  if (!deviceRes?.device_id) return false

  const res = await fetchJson("/auth/extension_token", {
    method: "POST",
    body: JSON.stringify({ device_id: deviceRes.device_id })
  })

  if (!res.ok) return false

  const body = await res.json()
  if (!body.token) return false

  const stored = await sendToExtension({
    type: "qadabra:auth:store-token",
    token: body.token
  })
  return !!stored?.ok
}

export async function exchangeExtensionToken() {
  const vault = await sendToExtension({ type: "qadabra:auth:get-token" })
  if (!vault?.token || !vault?.device_id) return false

  const res = await fetchJson("/auth/extension_exchange", {
    method: "POST",
    body: JSON.stringify({ token: vault.token, device_id: vault.device_id })
  })

  if (res.status === 204) {
    reconnectLiveSocket()
    return true
  }

  if (res.status === 422) {
    try {
      const body = await res.json()
      if (body.error === "token_expired" || body.error === "token_invalidated" || body.error === "invalid_token") {
        await sendToExtension({ type: "qadabra:auth:clear-token" })
      }
    } catch (_e) {
      // ignore
    }
  }

  return false
}

export async function globalExtensionLogout() {
  const vault = await sendToExtension({ type: "qadabra:auth:get-token" })
  if (vault?.token) {
    try {
      await fetchJson("/auth/invalidate_extension_token", {
        method: "POST",
        body: JSON.stringify({ token: vault.token })
      })
    } catch (_e) {
      // continue logout even if invalidate fails
    }
  }

  await sendToExtension({ type: "qadabra:auth:logout" })
}

let bridgeStarted = false
let logoutWired = false

function wireGlobalLogoutIntercept() {
  if (logoutWired) return
  logoutWired = true

  document.addEventListener(
    "submit",
    async (event) => {
      const form = event.target
      if (!(form instanceof HTMLFormElement)) return
      if (!form.action || !form.action.includes("/logout")) return

      event.preventDefault()
      try {
        await globalExtensionLogout()
      } finally {
        HTMLFormElement.prototype.submit.call(form)
      }
    },
    true
  )
}

export async function startExtensionAuthBridge() {
  if (bridgeStarted) return
  bridgeStarted = true
  wireGlobalLogoutIntercept()

  const { present, authed: extAuthed } = await probeExtension()
  if (!present) return

  let sessionAuthed = false
  try {
    const statusRes = await fetchJson("/auth/session_status", { method: "GET" })
    if (statusRes.ok) {
      const body = await statusRes.json()
      sessionAuthed = !!body.authed
    }
  } catch (_e) {
    return
  }

  if (sessionAuthed) {
    await mintTokenIntoExtension()
    return
  }

  if (extAuthed) {
    await exchangeExtensionToken()
  }
}

// Optional LiveView hook for surfaces that want an explicit remount trigger.
export const ExtensionBridgeHook = {
  mounted() {
    startExtensionAuthBridge()
  }
}
