// Browser-extension identity bridge for Qadabra-origin pages / widget iframes.
//
// Authed session  → mint Phoenix.Token into extension vault
// Unauthed session + vault token → redeem via /auth/extension_exchange
//                                   then LiveSocket reconnect (SessionSync
//                                   remounts sibling LiveViews)
//
// Publisher host pages never call this; only Qadabra hosts + widget iframes.

import {
  broadcastWidgetLogout,
  clearAuthedTokens,
  isWidgetDocument,
  pageSyncId,
  reconnectWidgetSocket,
  setUpgradeToken
} from "../widget_socket"

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

function logoutNavigationPending() {
  return window.__qlariusLogoutNavigation === true
}

function reconnectLiveSocket() {
  // This page is already navigating to a fresh anonymous load.
  if (logoutNavigationPending()) return

  const socket = window.liveSocket
  if (!socket) {
    window.location.reload()
    return
  }

  // Widget iframes: no timed reload fallback (see widget_socket.js).
  if (isWidgetDocument()) {
    reconnectWidgetSocket(socket)
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

/**
 * Mint a vault token from the current Phoenix session.
 * @param {{ force?: boolean }} [opts] — `force: true` for intentional
 *   login (AuthFinalize / connect popup). Clears the post-logout guard.
 *   Default path refuses to mint while logout is settling.
 */
export async function mintTokenIntoExtension(opts = {}) {
  if (opts.force) {
    await sendToExtension({ type: "qadabra:auth:clear-logout-guard" })
  } else {
    const guard = await sendToExtension({ type: "qadabra:auth:logout-guard-active" })
    if (guard?.active) return false
  }

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
  const guard = await sendToExtension({ type: "qadabra:auth:logout-guard-active" })
  if (guard?.active) return false

  const vault = await sendToExtension({ type: "qadabra:auth:get-token" })
  if (!vault?.token || !vault?.device_id) return false

  // Widget iframes pass the host page's shared sync id so the sign-in
  // broadcast reaches sibling widgets that never received a cookie.
  const body = { token: vault.token, device_id: vault.device_id }
  if (isWidgetDocument()) {
    const syncId = pageSyncId()
    if (syncId) body.sync_id = syncId
  }

  const res = await fetchJson("/auth/extension_exchange", {
    method: "POST",
    body: JSON.stringify(body)
  })

  if (res.ok) {
    // The response carries a one-shot widget_token for browsers that drop
    // the Set-Cookie inside a third-party iframe; the reconnect below
    // mounts authed either way.
    try {
      const payload = await res.json()
      if (payload?.widget_token) setUpgradeToken(payload.widget_token)
    } catch (_e) {
      // 204 or non-JSON body: cookie path only.
    }
    lastSyncResult = "exchanged"
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
  lastSyncResult = null

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

// Last settled bridge outcome for this page — skip repeat probes on
// LiveSocket reconnect when nothing auth-related changed.
let lastSyncResult = null

/**
 * Reconcile Phoenix session ↔ extension vault.
 * Safe to call after every LiveSocket reconnect / SessionSync remount.
 *
 * @returns {"minted" | "exchanged" | "noop" | "absent"}
 */
export async function syncExtensionWithSession() {
  const { present, authed: extAuthed } = await probeExtension()
  if (!present) {
    lastSyncResult = "absent"
    return "absent"
  }

  // Disconnect set this guard so a still-authed vault cannot sign the
  // page back in before the anonymous load finishes.
  const guard = await sendToExtension({ type: "qadabra:auth:logout-guard-active" })
  if (guard?.active) {
    lastSyncResult = "noop"
    return "noop"
  }

  // Already aligned (session + vault) — avoid /auth/session_status storms.
  if (lastSyncResult === "noop" && extAuthed) return "noop"
  if (lastSyncResult === "minted" && extAuthed) return "noop"
  if (lastSyncResult === "exchanged" && extAuthed) return "noop"

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

  // Only mint when the vault is empty. Re-minting on every reconcile
  // rewrites storage, re-notifies frames, and loops.
  if (sessionAuthed) {
    if (extAuthed) {
      lastSyncResult = "noop"
      return "noop"
    }
    const guard = await sendToExtension({ type: "qadabra:auth:logout-guard-active" })
    if (guard?.active) {
      // Logout settling — content script clears this partition; do not remint.
      return "noop"
    }
    await mintTokenIntoExtension()
    lastSyncResult = "minted"
    return "minted"
  }

  if (extAuthed) {
    const exchanged = await exchangeExtensionToken()
    lastSyncResult = exchanged ? "exchanged" : "noop"
    return lastSyncResult
  }

  lastSyncResult = "noop"
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
      window.__qlariusLogoutNavigation = true

      const body = new URLSearchParams(new FormData(form))
      const csrf = body.get("_csrf_token") || csrfToken()
      const returnTo = body.get("return_to")
      const dest =
        returnTo && returnTo.startsWith("/") && !returnTo.startsWith("//")
          ? returnTo
          : "/hi?reconnect=1"

      // Clear the vault first so another frame cannot mint a new token.
      // That also posts /logout from the content script, which rotates the
      // CSRF secret. Submitting this form afterwards navigates to a bare
      // Forbidden page, so finish here and go to the destination ourselves.
      try {
        await globalExtensionLogout()
      } catch (_e) {
        // Extension optional; the fetch below still clears this session.
      }

      let cleared = false
      try {
        const res = await fetch(form.action, {
          method: "POST",
          credentials: "same-origin",
          redirect: "follow",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "x-csrf-token": csrf,
            Accept: "text/html"
          },
          body: body.toString()
        })
        cleared = res.type === "opaqueredirect" || res.status === 403 || res.ok
      } catch (_e) {
        cleared = false
      }

      if (cleared) {
        window.location.assign(dest)
      } else {
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
    if (logoutNavigationPending()) return

    if (event.data?.type === "qadabra:extension-hello" && event.data.id) {
      const prev = document.documentElement.dataset.qadabraExtensionId
      document.documentElement.dataset.qadabraExtensionId = event.data.id
      // First hello only — repeats would re-enter sync/mint forever.
      if (prev !== event.data.id) syncExtensionWithSessionDebounced()
      return
    }

    if (event.data?.type === "qadabra:auth:please-reconnect") {
      // Content script already exchanged or cleared this frame's session.
      // Inside a cookieless widget it forwards the exchange's widget_token.
      lastSyncResult = null
      if (event.data.widget_token) setUpgradeToken(event.data.widget_token)
      // Extension logout: a token-backed widget has no cookie partition to
      // clear, so drop the client token and remount anonymous.
      if (event.data.reason === "extension_logout") {
        clearAuthedTokens()
        broadcastWidgetLogout()
      }
      reconnectLiveSocket()
      return
    }

    if (event.data?.type !== "qadabra:auth:extension-changed") return
    // Force re-probe after vault clear / cross-frame auth change.
    lastSyncResult = null
    syncExtensionWithSessionDebounced()
  })
}

export function syncExtensionWithSessionDebounced(opts = {}) {
  if (opts.reset) lastSyncResult = null
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
