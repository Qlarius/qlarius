// Top frame of every site. Brave often withholds both chrome.runtime and
// content scripts from a third-party qadabra.app iframe, so the iframe
// cannot reach the vault itself. This script can: it asks the service
// worker to redeem the vault and postMessages the one-shot widget socket
// token straight into the iframe.
//
// The vault identity token never leaves the service worker. The widget
// token is not written onto the publisher page; postMessage delivers it
// only to a Qadabra widget origin.

const delivered = new WeakSet();
const inflight = new WeakSet();
const attempted = new WeakMap();
let generation = 0;

function qadabraWidget(iframe) {
  let url;
  try {
    url = new URL(iframe.src, window.location.href);
  } catch (_err) {
    return null;
  }

  const host = url.hostname;
  const ours =
    host === "qadabra.app" ||
    host.endsWith(".qadabra.app") ||
    host === "qlinkin.bio" ||
    host === "www.qlinkin.bio" ||
    host === "localhost" ||
    host.endsWith(".gigalixirapp.com");

  if (!ours || !url.pathname.startsWith("/widgets/")) return null;
  return { origin: url.origin, syncId: url.searchParams.get("sync_id") };
}

function framesIn(win, found) {
  let iframes;
  try {
    iframes = win.document.querySelectorAll("iframe");
  } catch (_err) {
    return;
  }

  iframes.forEach((iframe) => {
    found.push(iframe);
    try {
      framesIn(iframe.contentWindow, found);
    } catch (_err) {
      // Cross-origin frame. Its own document is not ours to walk.
    }
  });
}

async function relayFrame(iframe) {
  if (delivered.has(iframe) || inflight.has(iframe)) return;
  if (attempted.get(iframe) === generation) return;
  const target = qadabraWidget(iframe);
  if (!target || !iframe.contentWindow) return;

  inflight.add(iframe);
  attempted.set(iframe, generation);
  let response = null;
  try {
    response = await chrome.runtime.sendMessage({
      type: "qadabra:auth:relay-widget",
      sync_id: target.syncId
    });
  } catch (_err) {
    response = null;
  }
  inflight.delete(iframe);

  if (!response?.widget_token || !iframe.contentWindow) return;

  delivered.add(iframe);
  iframe.contentWindow.postMessage(
    {
      type: "qadabra:auth:please-reconnect",
      reason: "extension_exchange",
      widget_token: response.widget_token
    },
    target.origin
  );
}

function scan() {
  const found = [];
  framesIn(window, found);
  found.forEach((iframe) => {
    relayFrame(iframe);
  });
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "local") return;
  const tokenAdded = Object.entries(changes).some(
    ([key, change]) =>
      (key === "qadabra_identity_token" || key.startsWith("qadabra_identity_token_")) &&
      change.newValue &&
      !change.oldValue
  );
  if (!tokenAdded) return;
  generation += 1;
  scan();
});

scan();

const observer = new MutationObserver(() => scan());
observer.observe(document.documentElement, {
  childList: true,
  subtree: true,
  attributes: true,
  attributeFilter: ["src"]
});
