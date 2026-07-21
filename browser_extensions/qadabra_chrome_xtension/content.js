// Injected on Qadabra-family pages (including widget iframes).
//
// The extension popup, first-party qadabra.app tabs, and publisher widget
// iframes sit in different cookie partitions — a session in one does not
// appear in the others. The shared vault is the bridge:
//
//   authed page + empty vault  → mint identity token into vault
//   vault token + anon page    → extension_exchange → LiveSocket reconnect
//   vault cleared (logout)     → CSRF /logout in THIS frame → reconnect
//
// The service worker's remote_logout only clears the first-party cookie jar.
// Third-party embed partitions must clear themselves here.

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

// Clear THIS frame's partitioned Phoenix session, then remount LiveViews.
// Required for third-party widgets — SW fetch cannot touch their CHIPS jar.
let partitionClearInFlight = null;

async function clearPartitionSession() {
  if (partitionClearInFlight) return partitionClearInFlight;

  partitionClearInFlight = (async () => {
    settledKey = "0:0";

    const csrf = csrfToken();
    if (!csrf) {
      askPageReconnect("extension_logout");
      return;
    }

    try {
      const authed = await sessionAuthed();
      if (authed) {
        // Same pattern as SponsterWidgetBridge.sessionLogout — clears the
        // cookie partition that issued this request.
        await fetch("/logout", {
          method: "POST",
          credentials: "include",
          redirect: "manual",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "x-csrf-token": csrf,
            Accept: "text/html"
          },
          body: "_method=delete"
        });
      }
    } catch (_err) {
      // Best-effort; still reconnect so LV can reflect anon state.
    }

    askPageReconnect("extension_logout");
  })().finally(() => {
    partitionClearInFlight = null;
  });

  return partitionClearInFlight;
}

let reconcileInFlight = null;

async function reconcileFromVault() {
  publishExtensionId();

  if (!csrfToken()) return;

  const vault = await getVault();
  if (!vault?.ok) return;

  if (await logoutGuardActive()) {
    // Logout in flight — clear this partition if still authed, never mint.
    if (!vault.token) {
      await clearPartitionSession();
      return;
    }
    settledKey = null;
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

  // Vault cleared — clear THIS partition's session (not just settle anon).
  if (tokenGone) {
    clearPartitionSession();
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
    clearPartitionSession();
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
