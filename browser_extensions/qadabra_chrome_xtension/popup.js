// Extension popup — iframe host for the LiveView app.
// Env switcher is hidden unless unlocked (dev) or already on Local.

const ALLOWED_ORIGINS = [
  "https://localhost:4001",
  "http://localhost:4001",
  "http://localhost:4000",
  "https://qadabra.app",
  "https://www.qadabra.app",
  "https://qlink.qadabra.app",
  "https://qlarius.gigalixirapp.com"
];

const frame = document.getElementById("app-frame");
const envBar = document.getElementById("env-bar");
const envReveal = document.getElementById("env-reveal");
const hint = document.getElementById("env-hint");
const buttons = {
  prod: document.getElementById("env-prod"),
  local: document.getElementById("env-local")
};

let revealClicks = [];

function isAllowedOrigin(origin) {
  return origin && ALLOWED_ORIGINS.some((allowed) => origin === allowed);
}

async function isDevEnvUiUnlocked() {
  const data = await chrome.storage.local.get(QADABRA_DEV_ENV_UI_KEY);
  return !!data[QADABRA_DEV_ENV_UI_KEY];
}

async function setDevEnvUiUnlocked(unlocked) {
  await chrome.storage.local.set({ [QADABRA_DEV_ENV_UI_KEY]: !!unlocked });
}

async function syncEnvBarVisibility(env) {
  // Always show on Local so you can switch back without hunting for the unlock.
  const show = env.id === "local" || (await isDevEnvUiUnlocked());
  envBar.classList.toggle("visible", show);
}

function paintEnv(env) {
  Object.entries(buttons).forEach(([id, btn]) => {
    btn.classList.toggle("active", id === env.id);
  });
  hint.textContent = env.id === "local" ? env.appOrigin : "qadabra.app";
  frame.src = qadabraPopupUrl(env);
  syncEnvBarVisibility(env);
}

async function loadEnv() {
  const res = await chrome.runtime.sendMessage({ type: "qadabra:env:get" });
  if (res?.ok && res.config) {
    paintEnv(res.config);
  } else {
    paintEnv(await getQadabraEnv());
  }
}

async function switchEnv(envId) {
  const res = await chrome.runtime.sendMessage({
    type: "qadabra:env:set",
    env: envId
  });
  if (res?.ok && res.config) {
    paintEnv(res.config);
  }
}

async function toggleDevEnvUi() {
  const next = !(await isDevEnvUiUnlocked());
  await setDevEnvUiUnlocked(next);
  await syncEnvBarVisibility(await getQadabraEnv());
}

buttons.prod.addEventListener("click", () => switchEnv("prod"));
buttons.local.addEventListener("click", () => switchEnv("local"));

// Quintuple-click the invisible 4px top strip to unlock/lock the switcher.
envReveal.addEventListener("click", () => {
  const now = Date.now();
  revealClicks = revealClicks.filter((t) => now - t < 1500);
  revealClicks.push(now);
  if (revealClicks.length >= 5) {
    revealClicks = [];
    toggleDevEnvUi();
  }
});

// Works when the popup chrome (not the iframe) has focus.
document.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "e") {
    event.preventDefault();
    toggleDevEnvUi();
  }
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  if (changes[QADABRA_DEV_ENV_UI_KEY] || changes[QADABRA_ENV_KEY]) {
    getQadabraEnv().then(syncEnvBarVisibility);
  }
});

window.addEventListener("message", (event) => {
  if (!isAllowedOrigin(event.origin)) return;

  if (event.data?.status === "liveview-mounted") {
    chrome.runtime.sendMessage({ action: "refresh_ad_count" });
  } else if (event.data?.status === "liveview-not-mounted") {
    console.warn("⚠️ LiveView not mounted in iframe");
  }

  if (event.data?.type === "ads_updated") {
    chrome.runtime.sendMessage({ action: "refresh_ad_count" });
  }
});

loadEnv().then(() => {
  chrome.runtime.sendMessage({ action: "refresh_ad_count" });
});
