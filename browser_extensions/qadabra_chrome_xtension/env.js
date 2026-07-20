// Shared Local / Prod environment config for the Qadabra extension.
// Loaded via importScripts (service worker) and <script> (popup / options).

const QADABRA_ENV_KEY = "qadabra_env";
const QADABRA_DEVICE_KEY = "qadabra_device_id";
const QADABRA_LEGACY_TOKEN_KEY = "qadabra_identity_token";
// When true, popup shows the Local/Prod switcher. Off by default for prod UX.
const QADABRA_DEV_ENV_UI_KEY = "qadabra_dev_env_ui";

const QADABRA_ENVS = {
  prod: {
    id: "prod",
    label: "Prod",
    badge: "",
    appOrigin: "https://qadabra.app",
    popupPath: "/home?extension=true&popup=true&context=chrome_extension",
    apiBase: "https://qadabra.app",
    logoutHosts: [
      "https://qadabra.app",
      "https://qlink.qadabra.app",
      "https://qlinkin.bio",
      "https://www.qlinkin.bio"
    ]
  },
  local: {
    id: "local",
    label: "Local",
    badge: "L",
    // Match config/dev.exs public_app_scheme / host (HTTPS on 4001).
    appOrigin: "https://localhost:4001",
    popupPath: "/home?extension=true&popup=true&context=chrome_extension",
    apiBase: "https://localhost:4001",
    logoutHosts: [
      "https://localhost:4001",
      "http://localhost:4001",
      "http://localhost:4000"
    ]
  }
};

function qadabraTokenKey(envId) {
  return `qadabra_identity_token_${envId || "prod"}`;
}

async function getQadabraEnvId() {
  const data = await chrome.storage.local.get(QADABRA_ENV_KEY);
  const id = data[QADABRA_ENV_KEY];
  return id === "local" ? "local" : "prod";
}

async function getQadabraEnv() {
  const id = await getQadabraEnvId();
  return QADABRA_ENVS[id];
}

async function setQadabraEnvId(envId) {
  const id = envId === "local" ? "local" : "prod";
  await chrome.storage.local.set({ [QADABRA_ENV_KEY]: id });
  return QADABRA_ENVS[id];
}

function qadabraPopupUrl(env) {
  return `${env.appOrigin}${env.popupPath}`;
}
