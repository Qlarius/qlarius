// Cookieless widget auth, client side.
//
// Widget iframes (`/widgets/*`) live on publisher pages. Browsers that block
// third-party cookies never send `_qlarius_key`, so the LiveView join used to
// fail with "stale" and Phoenix reloaded the iframe in a loop. The server now
// accepts a signed `widget_token` on `/widgets/live`; this module keeps the
// current token, hands it to LiveSocket params, caps reloads, and upgrades
// the connection in place when the extension or the Connect popup produces
// an authed token.
//
// Only loaded behaviour changes on embed documents (`<meta name="widget-socket">`).

const RELOAD_CAP = 2
const RELOAD_WINDOW_MS = 10_000
const RELOAD_KEY = "qadabra:widget-reloads"

function meta(name) {
  return document.querySelector(`meta[name='${name}']`)?.getAttribute("content") || null
}

export function isWidgetDocument() {
  return !!meta("widget-socket")
}

export function widgetSocketPath() {
  return meta("widget-socket") || "/live"
}

export function isEmbeddedIframe() {
  try {
    return window.self !== window.top
  } catch (_e) {
    return true
  }
}

export function pageSyncId() {
  return new URLSearchParams(window.location.search).get("sync_id")
}

// Origin of the publisher page, from the `host_url` the loader script
// passes. Used to accept `postMessage`s from the parent and nothing else.
export function hostOrigin() {
  const hostUrl = new URLSearchParams(window.location.search).get("host_url")
  if (!hostUrl) return null
  try {
    return new URL(hostUrl).origin
  } catch (_e) {
    return null
  }
}

// --- token holder ----------------------------------------------------------

let currentToken = meta("widget-token")
let upgradeToken = null

export function widgetToken() {
  return upgradeToken || currentToken
}

// A one-shot authed token from the exchange or the popup. Consumed on the
// next connect; the server pushes a renewable session token afterwards.
export function setUpgradeToken(token) {
  if (typeof token === "string" && token) upgradeToken = token
}

export function setSessionToken(token) {
  if (typeof token !== "string" || !token) return
  currentToken = token
  upgradeToken = null
}

export function clearAuthedTokens() {
  upgradeToken = null
  currentToken = meta("widget-token")
}

// --- reload cap ------------------------------------------------------------

function readReloads() {
  try {
    const raw = sessionStorage.getItem(RELOAD_KEY)
    if (!raw) return []
    const list = JSON.parse(raw)
    const cutoff = Date.now() - RELOAD_WINDOW_MS
    return Array.isArray(list) ? list.filter((t) => typeof t === "number" && t > cutoff) : []
  } catch (_e) {
    return []
  }
}

function writeReloads(list) {
  try {
    sessionStorage.setItem(RELOAD_KEY, JSON.stringify(list))
  } catch (_e) {}
}

// Returns true when a reload is allowed and records it. After `RELOAD_CAP`
// reloads inside `RELOAD_WINDOW_MS` the widget stays put and shows the
// state it has instead of looping.
export function recordReloadAttempt() {
  const recent = readReloads()
  if (recent.length >= RELOAD_CAP) return false
  recent.push(Date.now())
  writeReloads(recent)
  return true
}

export function reloadCapReached() {
  return readReloads().length >= RELOAD_CAP
}

function markCapped() {
  console.warn("[widget] reload cap reached; staying on current mount")
  document.documentElement.dataset.widgetReloadCapped = "true"
}

function sameDocument(to) {
  try {
    const target = new URL(to, window.location.href)
    return target.pathname === window.location.pathname && target.search === window.location.search
  } catch (_e) {
    return false
  }
}

// LiveView answers a `stale`/`unauthorized` join with
// `liveSocket.redirect(root.href)`, i.e. a same-URL page load with no
// counter; `reloadWithJitter` ends in the same place. With `WidgetSocket` a
// missing cookie no longer fails the join, so such a redirect in a widget
// means something else is off (bad token, mid-deploy). Let the first two
// through, then keep whatever is on screen. Redirects to a different URL
// (real navigation) pass untouched.
export function installReloadGuard(liveSocket) {
  if (!isWidgetDocument() || liveSocket.__qadabraReloadGuard) return
  liveSocket.__qadabraReloadGuard = true

  const originalRedirect = liveSocket.redirect.bind(liveSocket)
  liveSocket.redirect = (to, flash, reloadToken) => {
    if (sameDocument(to) && !recordReloadAttempt()) {
      markCapped()
      return
    }
    originalRedirect(to, flash, reloadToken)
  }

  const originalReload = window.location.reload.bind(window.location)
  try {
    Object.defineProperty(window.location, "reload", {
      configurable: true,
      value: () => {
        if (recordReloadAttempt()) originalReload()
        else markCapped()
      }
    })
  } catch (_e) {
    // Some engines refuse to redefine Location members; the redirect wrap
    // above still covers LiveView's own reload paths.
  }
}

// --- reconnect -------------------------------------------------------------

// Widgets never fall back to a timed `location.reload()`: a failed
// reconnect in an iframe should leave the current (anonymous) state visible
// rather than start a loop.
export function reconnectWidgetSocket(liveSocket, { onOpen } = {}) {
  if (!liveSocket) return
  const rawSocket =
    typeof liveSocket.socket === "function" ? liveSocket.socket() : liveSocket.socket
  if (rawSocket && typeof rawSocket.onOpen === "function" && typeof onOpen === "function") {
    const ref = rawSocket.onOpen(() => {
      try {
        rawSocket.off([ref])
      } catch (_e) {}
      onOpen()
    })
  }
  liveSocket.disconnect()
  liveSocket.connect()
}

// Server pushes a renewable session token after a token-backed authed
// mount (`QlariusWeb.WidgetSessionHooks`).
export function listenForSessionTokens() {
  if (!isWidgetDocument()) return
  window.addEventListener("phx:qadabra:widget-session-token", (e) => {
    setSessionToken(e.detail?.token)
  })
}

// --- parent page hints -----------------------------------------------------

// The loader script probes the extension from the publisher page and posts
// `sponster_extension_present`. Accept it only from that page's origin.
export function listenForParentExtensionHint(onPresent) {
  if (!isWidgetDocument() || !isEmbeddedIframe()) return
  const expected = hostOrigin()
  if (!expected) return

  window.addEventListener("message", (e) => {
    if (e.origin !== expected) return
    if (e.source !== window.parent) return
    if (e.data?.type !== "sponster_extension_present") return
    onPresent({ authed: !!e.data.authed })
  })
}

// --- Storage Access --------------------------------------------------------

// Browsers that partition cookies may grant the iframe its first-party
// cookie after a user gesture. Called from the Connect click; a success
// means the next reconnect carries the real cookie. Failure is fine — the
// token path still works.
export async function requestStorageAccess() {
  if (!isEmbeddedIframe()) return false
  if (typeof document.requestStorageAccess !== "function") return false
  try {
    if (typeof document.hasStorageAccess === "function" && (await document.hasStorageAccess())) {
      return true
    }
    await document.requestStorageAccess()
    return true
  } catch (_e) {
    return false
  }
}
