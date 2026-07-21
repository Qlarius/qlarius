importScripts("env.js");

const POLL_INTERVAL_MS = 5 * 60 * 1000;

let notificationTimer;
let adCountPoller;
let cachedAdCount = 0;
let cachedOfferedAmount = 0;

chrome.runtime.onInstalled.addListener(async () => {
  chrome.action.setBadgeBackgroundColor({ color: "#e36159" });
  chrome.action.setBadgeTextColor({ color: "#fff" });
  await ensureDeviceId();
  await refreshEnvBadge();
  fetchAdCount();
  startAdCountPolling();
  startNotificationTimer();
});

chrome.runtime.onStartup.addListener(async () => {
  await ensureDeviceId();
  await refreshEnvBadge();
  fetchAdCount();
  startAdCountPolling();
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (changes[QADABRA_ENV_KEY]) {
    refreshEnvBadge();
    fetchAdCount();
  }
});

// Hidden Local/Prod UI unlock — works even when the popup iframe has focus.
chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "toggle-env-ui") return;
  const data = await chrome.storage.local.get(QADABRA_DEV_ENV_UI_KEY);
  await chrome.storage.local.set({
    [QADABRA_DEV_ENV_UI_KEY]: !data[QADABRA_DEV_ENV_UI_KEY]
  });
});

async function refreshEnvBadge() {
  const env = await getQadabraEnv();
  const color = env.id === "local" ? "#2563eb" : "#e36159";
  chrome.action.setBadgeTextColor({ color: "#fff" });
  chrome.action.setBadgeBackgroundColor({ color });

  // Ad count wins when present; Local shows "L" when zero so the env is obvious.
  if (cachedAdCount > 0) {
    chrome.action.setBadgeText({ text: String(cachedAdCount) });
  } else {
    chrome.action.setBadgeText({ text: env.badge || "" });
  }
}

async function ensureDeviceId() {
  const existing = await chrome.storage.local.get(QADABRA_DEVICE_KEY);
  if (existing[QADABRA_DEVICE_KEY]) return existing[QADABRA_DEVICE_KEY];

  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  const deviceId = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  await chrome.storage.local.set({ [QADABRA_DEVICE_KEY]: deviceId });
  return deviceId;
}

async function getVault() {
  const env = await getQadabraEnv();
  const key = qadabraTokenKey(env.id);
  const data = await chrome.storage.local.get([
    key,
    QADABRA_LEGACY_TOKEN_KEY,
    QADABRA_DEVICE_KEY
  ]);

  let token = data[key] || null;

  // One-time migrate pre-namespace vault into prod.
  if (!token && env.id === "prod" && data[QADABRA_LEGACY_TOKEN_KEY]) {
    token = data[QADABRA_LEGACY_TOKEN_KEY];
    await chrome.storage.local.set({ [key]: token });
    await chrome.storage.local.remove(QADABRA_LEGACY_TOKEN_KEY);
  }

  return {
    token,
    device_id: data[QADABRA_DEVICE_KEY] || null,
    env_id: env.id
  };
}

async function notifyOpenTabs(state, extra = {}) {
  // Content scripts also see chrome.storage.onChanged. Fan out once per
  // frame via sendMessage only — executeScript+postMessage was doubling
  // reconciles (session_status stampede across every widget iframe).
  // Every Qadabra frame (incl. third-party widget iframes) must hear
  // anonymous so it can CSRF-logout its own cookie partition.
  try {
    const tabs = await chrome.tabs.query({});
    await Promise.all(
      tabs.map(async (tab) => {
        if (!tab.id) return;

        const payload = {
          type: "qadabra:auth:extension-changed",
          state,
          ...extra
        };

        try {
          const frames = await chrome.webNavigation.getAllFrames({ tabId: tab.id });
          await Promise.all(
            (frames || [{ frameId: 0 }]).map(async (frame) => {
              try {
                await chrome.tabs.sendMessage(tab.id, payload, {
                  frameId: frame.frameId
                });
              } catch (_err) {
                // Frame has no content script — ignore.
              }
            })
          );
        } catch (_err) {
          try {
            await chrome.tabs.sendMessage(tab.id, payload);
          } catch (_e) {
            // ignore
          }
        }
      })
    );
  } catch (_err) {
    // Best-effort fan-out.
  }
}

async function storeToken(token) {
  if (!token || typeof token !== "string") return false;
  // Reject re-mint while logout is settling (popup session often still
  // authed for one tick and would otherwise vault a fresh token).
  if (await underLogoutGuard()) return false;

  await ensureDeviceId();
  const env = await getQadabraEnv();
  const key = qadabraTokenKey(env.id);
  const existing = await chrome.storage.local.get(key);
  // Same token already vaulted — skip write/notify to avoid mint loops.
  if (existing[key] === token) return true;

  await chrome.storage.local.set({ [key]: token });
  await notifyOpenTabs("authed");
  fetchAdCount();
  return true;
}

async function clearToken() {
  const env = await getQadabraEnv();
  await chrome.storage.local.remove(qadabraTokenKey(env.id));
  cachedAdCount = 0;
  cachedOfferedAmount = 0;
  await refreshEnvBadge();
  await notifyOpenTabs("anonymous");
}

async function globalLogout() {
  // Guard FIRST so any still-authed frame that sees an empty vault cannot
  // mint a replacement token before cookies finish clearing.
  await setLogoutGuard();

  const vault = await getVault();
  const token = vault.token;
  const env = await getQadabraEnv();

  // Drop the vault before remote logout fan-out so exchanges cannot race.
  await clearToken();

  if (token) {
    await Promise.all(
      env.logoutHosts.map(async (origin) => {
        try {
          await fetch(`${origin}/auth/extension_remote_logout`, {
            method: "POST",
            credentials: "include",
            headers: {
              Accept: "application/json",
              "Content-Type": "application/json"
            },
            body: JSON.stringify({ token })
          });
        } catch (_err) {
          // Best-effort; current-origin logout still runs from the page.
        }
      })
    );
  }
}

function isAllowedExternalSender(sender) {
  const url = sender?.url || sender?.origin || "";
  try {
    const { hostname, protocol } = new URL(url);
    if (protocol !== "https:" && !(protocol === "http:" && hostname === "localhost")) {
      return false;
    }
    return (
      hostname === "qadabra.app" ||
      hostname.endsWith(".qadabra.app") ||
      hostname === "qlinkin.bio" ||
      hostname === "www.qlinkin.bio" ||
      hostname === "localhost" ||
      hostname.endsWith(".gigalixirapp.com")
    );
  } catch (_e) {
    return false;
  }
}

async function handleAuthMessage(message) {
  switch (message?.type) {
    case "qadabra:auth:probe": {
      const vault = await getVault();
      return { ok: true, authed: !!vault.token, env: vault.env_id };
    }
    case "qadabra:auth:get-device-id": {
      const device_id = await ensureDeviceId();
      return { ok: true, device_id };
    }
    case "qadabra:auth:get-token": {
      const vault = await getVault();
      if (!vault.device_id) vault.device_id = await ensureDeviceId();
      return {
        ok: true,
        token: vault.token,
        device_id: vault.device_id,
        env: vault.env_id
      };
    }
    case "qadabra:auth:store-token": {
      const ok = await storeToken(message.token);
      return { ok };
    }
    case "qadabra:auth:clear-logout-guard": {
      await clearLogoutGuard();
      return { ok: true };
    }
    case "qadabra:auth:logout-guard-active": {
      return { ok: true, active: await underLogoutGuard() };
    }
    case "qadabra:auth:clear-token": {
      await setLogoutGuard();
      await clearToken();
      return { ok: true };
    }
    case "qadabra:auth:logout": {
      await globalLogout();
      return { ok: true };
    }
    case "qadabra:env:get": {
      const env = await getQadabraEnv();
      return { ok: true, env: env.id, config: env };
    }
    case "qadabra:env:set": {
      const env = await setQadabraEnvId(message.env);
      // Don't show the previous env's count while the new one loads.
      cachedAdCount = 0;
      cachedOfferedAmount = 0;
      await refreshEnvBadge();
      fetchAdCount();
      const vault = await getVault();
      await notifyOpenTabs(vault.token ? "authed" : "anonymous");
      return { ok: true, env: env.id, config: env };
    }
    default:
      return null;
  }
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.action === "refresh_ad_count") {
    fetchAdCount();
    sendResponse({ ok: true });
    return false;
  }

  if (
    message?.type &&
    (String(message.type).startsWith("qadabra:auth:") ||
      String(message.type).startsWith("qadabra:env:"))
  ) {
    handleAuthMessage(message).then(sendResponse);
    return true;
  }

  return false;
});

chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
  if (!isAllowedExternalSender(sender)) {
    sendResponse({ ok: false, error: "origin_denied" });
    return false;
  }

  if (message?.type && String(message.type).startsWith("qadabra:auth:")) {
    handleAuthMessage(message).then(sendResponse);
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
  return false;
});

function isAuthRedirect(response) {
  // API `:require_authenticated_user` redirects to /connect. With
  // redirect:"manual" we see 3xx; without it fetch can land on HTML 200.
  return (
    response.type === "opaqueredirect" ||
    response.status === 301 ||
    response.status === 302 ||
    response.status === 303 ||
    response.status === 307 ||
    response.status === 308 ||
    response.status === 401
  );
}

async function exchangeVaultForSession(env, vault) {
  if (!vault?.token) return false;

  const deviceId = vault.device_id || (await ensureDeviceId());

  try {
    const res = await fetch(`${env.apiBase}/auth/extension_exchange`, {
      method: "POST",
      credentials: "include",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ token: vault.token, device_id: deviceId })
    });
    return res.status === 204 || res.ok;
  } catch (error) {
    console.warn("extension_exchange failed:", error.message);
    return false;
  }
}

async function fetchAdCountFromApi(env) {
  return fetch(`${env.apiBase}/api/extension/ad_count`, {
    credentials: "include",
    redirect: "manual",
    headers: { Accept: "application/json" }
  });
}

async function fetchAdCount() {
  try {
    const env = await getQadabraEnv();
    const vault = await getVault();

    let response = await fetchAdCountFromApi(env);

    if (isAuthRedirect(response)) {
      if (!vault.token) {
        cachedAdCount = 0;
        cachedOfferedAmount = 0;
        await refreshEnvBadge();
        return;
      }

      const exchanged = await exchangeVaultForSession(env, vault);
      if (!exchanged) {
        console.warn("Ad count: vault exchange failed for", env.id);
        await refreshEnvBadge();
        return;
      }

      response = await fetchAdCountFromApi(env);
    }

    if (!response.ok) {
      console.warn("Ad count fetch failed:", response.status, env.id);
      // Keep last good count; still refresh env color/marker.
      await refreshEnvBadge();
      return;
    }

    const contentType = response.headers.get("content-type") || "";
    if (!contentType.includes("application/json")) {
      console.warn("Ad count fetch: non-JSON response for", env.id);
      await refreshEnvBadge();
      return;
    }

    const data = await response.json();
    cachedAdCount = data.ads_count || 0;
    cachedOfferedAmount = data.offered_amount || 0;
    await refreshEnvBadge();
  } catch (error) {
    console.warn("Ad count fetch error:", error.message);
    // Network/TLS failures should not wipe a previously good badge.
    await refreshEnvBadge();
  }
}

function startAdCountPolling() {
  if (adCountPoller) clearInterval(adCountPoller);
  adCountPoller = setInterval(fetchAdCount, POLL_INTERVAL_MS);
}

function startNotificationTimer() {
  notificationTimer = setTimeout(() => {
    showNotification();

    notificationTimer = setInterval(() => {
      showNotification();
    }, 1800000);
  }, 6000);
}

function showNotification() {
  fetchAdCount().then(() => {
    if (cachedAdCount === 0) return;

    const amount = cachedOfferedAmount.toFixed(2);
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon128.png",
      title: "Sponster",
      message: `You have ${cachedAdCount} ads offering $${amount} in sponsorship. Click here to review.`,
      priority: 2
    });
  });
}

chrome.notifications.onClicked.addListener(() => {
  chrome.action.openPopup();
});
