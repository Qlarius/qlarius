(function () {
  "use strict";

  if (window.tiqitPassInitialized) {
    console.log("[Tiqit Pass] Already initialized, skipping");
    return;
  }
  window.tiqitPassInitialized = true;

  // Publisher pages must iframe Qadabra, not themselves.
  // Local demosite / tunnel hosts hit the local Phoenix app on :4001.
  function resolveBaseUrl() {
    var host = window.location.hostname;
    if (host === "localhost" || host === "127.0.0.1") {
      return "https://localhost:4001";
    }
    return "https://qadabra.app";
  }

  function revealGatedContent(marker) {
    var el = marker.nextElementSibling;
    while (el) {
      if (el.style) {
        el.style.display = "";
        el.style.visibility = "";
      }
      el = el.nextElementSibling;
    }
    marker.style.display = "none";
  }

  function dismissOverlay(iframe) {
    if (iframe && iframe.parentNode) {
      iframe.parentNode.removeChild(iframe);
    }
  }

  function initTiqitPassWidget() {
    console.log("[Tiqit Pass] Initializing widget...");
    var gate = document.getElementById("tiqit-pass-gate");
    if (!gate) {
      console.warn("Tiqit Pass: Marker #tiqit-pass-gate not found");
      return;
    }

    var catalogId = gate.getAttribute("data-catalog-id");
    if (!catalogId) {
      console.warn("Tiqit Pass: data-catalog-id attribute not found");
      return;
    }

    var homeHref = gate.getAttribute("data-home-href") || "index.html";
    var marker = document.getElementById("tiqit-pass-hide-start");
    var baseUrl = resolveBaseUrl();
    var iframeUrl =
      baseUrl + "/widgets/tiqit_pass/" + encodeURIComponent(catalogId) + "?force_theme=light";

    console.log("[Tiqit Pass] Creating iframe with URL:", iframeUrl);

    var iframe = document.createElement("iframe");
    iframe.id = "tiqit-pass-iframe";
    iframe.src = iframeUrl;
    iframe.setAttribute("allow", "fullscreen");
    iframe.setAttribute("title", "Tiqit Pass");
    iframe.style.cssText = [
      "position: fixed",
      "inset: 0",
      "width: 100%",
      "height: 100%",
      "border: 0",
      "background: transparent",
      "z-index: 999998",
      "color-scheme: normal"
    ].join(";");

    document.body.appendChild(iframe);
    console.log("[Tiqit Pass] Iframe injected successfully");

    window.addEventListener("message", function (event) {
      if (event.origin !== baseUrl) return;
      if (!event.data || typeof event.data !== "object") return;

      var type = event.data.type;
      console.log("[Tiqit Pass] Received postMessage:", type);

      if (type === "tiqit_purchased" || type === "tiqit_already_active") {
        dismissOverlay(iframe);
        if (marker) revealGatedContent(marker);
        return;
      }

      if (type === "tiqit_pass_back_home") {
        window.location.href = homeHref;
        return;
      }

      if (type === "open_sponster_drawer") {
        window.postMessage({ type: "open_sponster_drawer" }, window.location.origin);
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initTiqitPassWidget);
  } else {
    initTiqitPassWidget();
  }
})();
