// /Users/traenickelson/Documents/Qadabra/qlarius_chrome_xtension/popup.js
console.log('=== EXTENSION POPUP JS LOADED ===');

// Test if we can access the iframe
// const iframe = document.querySelector('iframe');
// console.log('Iframe element:', iframe);



// Monitor for any errors
// window.addEventListener('error', function(e) {
//   console.error('=== POPUP ERROR ===', e.error);
// });

// Check if LiveView is trying to connect
// setInterval(function() {
//   console.log('=== POPUP STATUS CHECK ===');
//   console.log('Iframe src:', iframe.src);
//   //console.log('Iframe readyState:', iframe.contentWindow?.document?.readyState);
// }, 5000);

window.addEventListener("message", (event) => {
  if (event.origin !== "https://localhost:4001") return;

  if (event.data.status === "liveview-mounted") {
    console.log("✅ LiveView is mounted inside the iframe!");
  } else if (event.data.status === "liveview-not-mounted") {
    console.warn("⚠️ LiveView is NOT mounted inside the iframe.");
  }
});

window.addEventListener("DOMContentLoaded", () => {
  const checkLiveViewMounted = () => {
    if (window.liveSocket && window.liveSocket.isConnected()) {
      window.parent.postMessage({ status: "liveview-mounted" }, "*");
    } else {
      window.parent.postMessage({ status: "liveview-not-mounted" }, "*");
    }
  };

  // Wait a bit for LiveView to initialize
  setTimeout(checkLiveViewMounted, 1000);
  });
  window.addEventListener("phx:page-loading-stop", () => {
if (window.liveSocket?.isConnected()) {
  window.parent.postMessage({ status: "liveview-connected" }, "*");
} else {
  window.parent.postMessage({ status: "liveview-connection-failed" }, "*");
}
});

window.onerror = function (msg, src, line, col, err) {
  window.parent.postMessage({ type: "iframe-error", msg, err }, "*");
};