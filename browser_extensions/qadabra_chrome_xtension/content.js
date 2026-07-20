// Injected on Qadabra-family pages (including widget iframes).
//
// The extension popup and publisher widget iframes sit in different cookie
// partitions, so a session in one does not appear in the other. The shared
// vault is the bridge:
//
//   authed page + empty vault  → mint identity token into vault
//   vault token + anon page    → extension_exchange → LiveSocket reconnect
//
// Mint/exchange run here (content script ↔ background) so they work even when
// the page's allowlisted extension-id meta tag doesn't match an unpacked build.

function publishExtensionId() {
  try {
    document.documentElement.dataset.qadabraExtensionId = chrome.runtime.id;
  } catch (_err) {
    // ignore
  }

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

function notifyPageBridge(state) {
  window.postMessage(
    { type: "qadabra:auth:extension-changed", state },
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

  if (await sessionAuthed()) {
    // Echo this partition's session into the shared vault so the extension
    // popup (and other partitions) can redeem it.
    if (!vault.token) {
      await mintIntoVault();
    } else {
      notifyPageBridge("authed");
    }
    return;
  }

  if (!vault.token) {
    notifyPageBridge("anonymous");
    return;
  }

  try {
    const ok = await exchangeVault(vault);
    if (ok) {
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
      key === "qadabra_env"
  );
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (!tokenOrEnvChanged(changes)) return;
  reconcileDebounced();
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== "qadabra:auth:extension-changed") return;
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
