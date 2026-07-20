// Browser-extension identity bridge for Qadabra-origin pages / widget iframes.
//
// Authed session  → mint Phoenix.Token into extension vault
// Unauthed session + vault token → redeem via /auth/extension_exchange
//                                   then LiveSocket reconnect (SessionSync
//                                   remounts sibling LiveViews)
//
// Publisher host pages never call this; only Qadabra hosts + widget iframes.

const PROBE_TIMEOUT_MS = 800

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""
}

function extensionRuntime() {
  return typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.sendMessage
    ? chrome.runtime
    : null
}

function extensionIds() {
  const ids = new Set()

  const meta = document
    .querySelector("meta[name='qadabra-extension-ids']")
    ?.getAttribute("content")
  if (meta) {
    meta
      .split(",")
      .map((s) => s.trim())
      .filter((id) => id && id !== "DEV_EXTENSION_ID_PLACEHOLDER")
      .forEach((id) => ids.add(id))
  }

  // Content script publishes the running extension's id (covers unpacked
  // extensions whose id is not in the server allowlist meta tag).
  const fromDom = document.documentElement?.dataset?.qadabraExtensionId
  if (fromDom) ids.add(fromDom)

  return [...ids]
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
      if (
        body.error === "token_expired" ||
        body.error === "token_invalidated" ||
        body.error === "invalid_token"
      ) {
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

/**
 * Reconcile Phoenix session ↔ extension vault.
 * Safe to call after every LiveSocket reconnect / SessionSync remount.
 *
 * @returns {"minted" | "exchanged" | "noop" | "absent"}
 */
export async function syncExtensionWithSession() {
  const { present, authed: extAuthed } = await probeExtension()
  if (!present) return "absent"

  let sessionAuthed = false
  try {
    const statusRes = await fetchJson("/auth/session_status", { method: "GET" })
    if (statusRes.ok) {
      const body = await statusRes.json()
      sessionAuthed = !!body.authed
    }
  } catch (_e) {
    return "noop"
  }

  if (sessionAuthed) {
    await mintTokenIntoExtension()
    return "minted"
  }

  if (extAuthed) {
    const exchanged = await exchangeExtensionToken()
    return exchanged ? "exchanged" : "noop"
  }

  return "noop"
}

let bridgeStarted = false
let logoutWired = false
let extensionPageListenerWired = false
let syncInFlight = null

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

function wireExtensionPageListener() {
  if (extensionPageListenerWired) return
  extensionPageListenerWired = true

  // Content script posts here when the vault token is stored/cleared
  // (including from the extension popup iframe on another host / cookie
  // partition). It may also perform exchange itself and ask us to reconnect.
  window.addEventListener("message", (event) => {
    if (event.origin !== window.location.origin) return

    if (event.data?.type === "qadabra:extension-hello" && event.data.id) {
      document.documentElement.dataset.qadabraExtensionId = event.data.id
      syncExtensionWithSessionDebounced()
      return
    }

    if (event.data?.type === "qadabra:auth:please-reconnect") {
      // Content script already redeemed the vault into this frame's session.
      reconnectLiveSocket()
      return
    }

    if (event.data?.type !== "qadabra:auth:extension-changed") return
    syncExtensionWithSessionDebounced()
  })
}

export function syncExtensionWithSessionDebounced() {
  if (syncInFlight) return syncInFlight
  syncInFlight = syncExtensionWithSession().finally(() => {
    syncInFlight = null
  })
  return syncInFlight
}

export async function startExtensionAuthBridge() {
  if (bridgeStarted) {
    await syncExtensionWithSessionDebounced()
    return
  }
  bridgeStarted = true
  wireGlobalLogoutIntercept()
  wireExtensionPageListener()
  await syncExtensionWithSessionDebounced()
}

// Optional LiveView hook for surfaces that want an explicit remount trigger.
export const ExtensionBridgeHook = {
  mounted() {
    startExtensionAuthBridge()
  }
}
