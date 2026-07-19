// Primary API host. Credentialed fetches send the shared
// `Domain=.qadabra.app` session cookie when present.
const API_BASE = "https://qadabra.app";
const AD_COUNT_ENDPOINT = `${API_BASE}/api/extension/ad_count`;
const POLL_INTERVAL_MS = 5 * 60 * 1000;

const STORAGE_TOKEN_KEY = "qadabra_identity_token";
const STORAGE_DEVICE_KEY = "qadabra_device_id";

// Hosts to clear on global logout (session cookies).
const LOGOUT_HOSTS = [
  "https://qadabra.app",
  "https://qlink.qadabra.app",
  "https://qlinkin.bio",
  "https://www.qlinkin.bio",
  "https://localhost:4001",
  "http://localhost:4000"
];

let notificationTimer;
let adCountPoller;
let cachedAdCount = 0;
let cachedOfferedAmount = 0;

chrome.runtime.onInstalled.addListener(() => {
  chrome.action.setBadgeBackgroundColor({ color: "#e36159" });
  chrome.action.setBadgeTextColor({ color: "#fff" });
  ensureDeviceId();
  fetchAdCount();
  startAdCountPolling();
  startNotificationTimer();
});

chrome.runtime.onStartup.addListener(() => {
  ensureDeviceId();
  fetchAdCount();
  startAdCountPolling();
});

async function ensureDeviceId() {
  const existing = await chrome.storage.local.get(STORAGE_DEVICE_KEY);
  if (existing[STORAGE_DEVICE_KEY]) return existing[STORAGE_DEVICE_KEY];

  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  const deviceId = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  await chrome.storage.local.set({ [STORAGE_DEVICE_KEY]: deviceId });
  return deviceId;
}

async function getVault() {
  const data = await chrome.storage.local.get([STORAGE_TOKEN_KEY, STORAGE_DEVICE_KEY]);
  return {
    token: data[STORAGE_TOKEN_KEY] || null,
    device_id: data[STORAGE_DEVICE_KEY] || null
  };
}

async function storeToken(token) {
  if (!token || typeof token !== "string") return false;
  await ensureDeviceId();
  await chrome.storage.local.set({ [STORAGE_TOKEN_KEY]: token });
  return true;
}

async function clearToken() {
  await chrome.storage.local.remove(STORAGE_TOKEN_KEY);
}

async function globalLogout() {
  const vault = await getVault();
  const token = vault.token;

  if (token) {
    await Promise.all(
      LOGOUT_HOSTS.map(async (origin) => {
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

  await clearToken();
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
      return { ok: true, authed: !!vault.token };
    }
    case "qadabra:auth:get-device-id": {
      const device_id = await ensureDeviceId();
      return { ok: true, device_id };
    }
    case "qadabra:auth:get-token": {
      const vault = await getVault();
      if (!vault.device_id) vault.device_id = await ensureDeviceId();
      return { ok: true, token: vault.token, device_id: vault.device_id };
    }
    case "qadabra:auth:store-token": {
      const ok = await storeToken(message.token);
      return { ok };
    }
    case "qadabra:auth:clear-token": {
      await clearToken();
      return { ok: true };
    }
    case "qadabra:auth:logout": {
      await globalLogout();
      return { ok: true };
    }
    default:
      return null;
  }
}

// Messages from extension pages (popup) and externally_connectable web pages.
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.action === "refresh_ad_count") {
    fetchAdCount();
    sendResponse({ ok: true });
    return false;
  }

  if (message?.type && String(message.type).startsWith("qadabra:auth:")) {
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

async function fetchAdCount() {
  try {
    const response = await fetch(AD_COUNT_ENDPOINT, {
      credentials: "include",
      headers: { Accept: "application/json" }
    });

    if (!response.ok) {
      console.warn("Ad count fetch failed:", response.status);
      return;
    }

    const data = await response.json();
    cachedAdCount = data.ads_count || 0;
    cachedOfferedAmount = data.offered_amount || 0;

    const badgeText = cachedAdCount > 0 ? String(cachedAdCount) : "";
    chrome.action.setBadgeText({ text: badgeText });
  } catch (error) {
    console.warn("Ad count fetch error:", error.message);
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
