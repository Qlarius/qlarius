const API_BASE = "https://qlarius.gigalixirapp.com";
const AD_COUNT_ENDPOINT = `${API_BASE}/api/extension/ad_count`;
const POLL_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

let notificationTimer;
let adCountPoller;
let cachedAdCount = 0;
let cachedOfferedAmount = 0;

chrome.runtime.onInstalled.addListener(() => {
  console.log("Extension installed or updated.");

  chrome.action.setBadgeBackgroundColor({ color: "#e36159" });
  chrome.action.setBadgeTextColor({ color: "#fff" });

  fetchAdCount();
  startAdCountPolling();
  startNotificationTimer();
});

chrome.runtime.onStartup.addListener(() => {
  fetchAdCount();
  startAdCountPolling();
});

async function fetchAdCount() {
  try {
    const response = await fetch(AD_COUNT_ENDPOINT, {
      credentials: "include",
      headers: { "Accept": "application/json" }
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
    console.log(`Badge updated: ${cachedAdCount} ads, $${cachedOfferedAmount.toFixed(2)}`);
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
    }, 1800000); // 30 minutes
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

chrome.runtime.onMessage.addListener((message) => {
  if (message.action === "refresh_ad_count") {
    fetchAdCount();
  }
});
