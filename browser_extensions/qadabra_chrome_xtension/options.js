const statusEl = document.getElementById("status");
const buttons = {
  prod: document.getElementById("env-prod"),
  local: document.getElementById("env-local")
};

function paint(env) {
  Object.entries(buttons).forEach(([id, btn]) => {
    btn.classList.toggle("active", id === env.id);
  });
  statusEl.textContent =
    env.id === "local"
      ? `Local — popup & API: ${env.appOrigin}. Badge shows “L”.`
      : `Prod — popup & API: ${env.appOrigin}.`;
}

async function load() {
  const res = await chrome.runtime.sendMessage({ type: "qadabra:env:get" });
  paint(res?.config || (await getQadabraEnv()));
}

async function switchEnv(envId) {
  const res = await chrome.runtime.sendMessage({
    type: "qadabra:env:set",
    env: envId
  });
  paint(res?.config || (await getQadabraEnv()));
}

buttons.prod.addEventListener("click", () => switchEnv("prod"));
buttons.local.addEventListener("click", () => switchEnv("local"));
load();
