// Injected on Qadabra-family pages (including widget iframes).
//
// The extension popup and publisher widget iframes sit in different cookie
// partitions, so a session in one does not appear in the other. The shared
// vault is the bridge:
//
//   authed page + empty vault  → mint identity token into vault
//   vault token + anon page    → extension_exchange → LiveSocket reconnect
//
// After logout, never re-mint from a frame that still has a warm session —
// that was bouncing the extension popup back into an authed state.

let helloPublished = false;
// "1:1" = session authed + vault token; "0:0" = anon + empty vault; null = unknown
let settledKey = null;

function publishExtensionId() {
  try {
    document.documentElement.dataset.qadabraExtensionId = chrome.runtime.id;
  } catch (_err) {
    // ignore
  }

  if (helloPublished) return;
  helloPublished = true;

  window.postMessage(
    { type: "qadabra:extension-hello", id: chrome.runtime.id },
    window.location.origin
  );
}

function askPageReconnect(reason) {
  window.postMessage(
    { type: "qadabra:auth:please-reconnect", reason: reason || "extension" },
    window.location.origin
  );
}

function csrfToken() {
  return (
    document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ||
    ""
  );
}

async function runtimeSend(message) {
  try {
    return await chrome.runtime.sendMessage(message);
  } catch (_err) {
    return null;
  }
}

async function getVault() {
  return runtimeSend({ type: "qadabra:auth:get-token" });
}

async function logoutGuardActive() {
  try {
    const data = await chrome.storage.local.get("qadabra_logout_guard_until");
    const until = data.qadabra_logout_guard_until;
    return typeof until === "number" && Date.now() < until;
  } catch (_err) {
    return false;
  }
}

async function sessionAuthed() {
  try {
    const res = await fetch("/auth/session_status", {
      credentials: "include",
      headers: { Accept: "application/json" }
    });
    if (!res.ok) return false;
    const body = await res.json();
    return !!body.authed;
  } catch (_err) {
    return false;
  }
}

async function mintIntoVault() {
  if (await logoutGuardActive()) return false;

  const device = await runtimeSend({ type: "qadabra:auth:get-device-id" });
  if (!device?.device_id) return false;

  const res = await fetch("/auth/extension_token", {
    method: "POST",
    credentials: "include",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "x-csrf-token": csrfToken()
    },
    body: JSON.stringify({ device_id: device.device_id })
  });

  if (!res.ok) return false;

  const body = await res.json();
  if (!body.token) return false;

  const stored = await runtimeSend({
    type: "qadabra:auth:store-token",
    token: body.token
  });
  return !!stored?.ok;
}

async function exchangeVault(vault) {
  if (await logoutGuardActive()) return false;

  const res = await fetch("/auth/extension_exchange", {
    method: "POST",
    credentials: "include",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "x-csrf-token": csrfToken()
    },
    body: JSON.stringify({
      token: vault.token,
      device_id: vault.device_id
    })
  });
  return res.status === 204;
}

let reconcileInFlight = null;

async function reconcileFromVault() {
  publishExtensionId();

  if (!csrfToken()) return;

  const vault = await getVault();
  if (!vault?.ok) return;

  if (await logoutGuardActive()) {
    // Logout in flight — do not mint or exchange.
    settledKey = vault.token ? null : "0:0";
    return;
  }

  // Skip network when this frame is already settled and the vault still matches.
  if (settledKey === "1:1" && vault.token) return;
  if (settledKey === "0:0" && !vault.token) return;

  const authed = await sessionAuthed();

  if (authed) {
    if (!vault.token) {
      const minted = await mintIntoVault();
      settledKey = minted ? "1:1" : null;
      return;
    }
    settledKey = "1:1";
    return;
  }

  if (!vault.token) {
    settledKey = "0:0";
    return;
  }

  try {
    const ok = await exchangeVault(vault);
    if (ok) {
      settledKey = "1:1";
      askPageReconnect("extension_exchange");
    }
  } catch (_err) {
    // Best-effort; page bridge may still retry.
  }
}

function reconcileDebounced() {
  if (reconcileInFlight) return reconcileInFlight;
  reconcileInFlight = reconcileFromVault().finally(() => {
    reconcileInFlight = null;
  });
  return reconcileInFlight;
}

function tokenOrEnvChanged(changes) {
  return Object.keys(changes).some(
    (key) =>
      key === "qadabra_identity_token" ||
      key.startsWith("qadabra_identity_token_") ||
      key === "qadabra_env" ||
      key === "qadabra_logout_guard_until"
  );
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (!tokenOrEnvChanged(changes)) return;

  if (changes.qadabra_env) {
    settledKey = null;
    reconcileDebounced();
    return;
  }

  const tokenGone = Object.entries(changes).some(
    ([key, change]) =>
      (key === "qadabra_identity_token" ||
        key.startsWith("qadabra_identity_token_")) &&
      !change.newValue
  );

  // Vault cleared (logout) — stay logged-out locally. Do NOT reconcile into
  // a mint while this frame's session cookie is still briefly warm.
  if (tokenGone) {
    settledKey = "0:0";
    return;
  }

  const tokenAdded = Object.entries(changes).some(
    ([key, change]) =>
      (key === "qadabra_identity_token" ||
        key.startsWith("qadabra_identity_token_")) &&
      change.newValue &&
      !change.oldValue
  );

  if (tokenAdded) settledKey = null;
  reconcileDebounced();
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== "qadabra:auth:extension-changed") return;

  if (message.state === "anonymous") {
    // Mirror vault clear — do not mint from a stale authed cookie.
    settledKey = "0:0";
    return;
  }

  settledKey = null;
  reconcileDebounced();
});

publishExtensionId();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => reconcileDebounced(), {
    once: true
  });
} else {
  reconcileDebounced();
}
