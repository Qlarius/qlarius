// Sponster third-party embed loader.
//
// Host pages include:
//
//   <div id="sponster-tipjar-widget" sponster-split-code="SPLIT_CODE"></div>
//   <script src="https://<qlarius-host>/sponster-tipjar-widget-ext-script.js"></script>
//
// This script injects a single bottom-anchored iframe pointing at
// /widgets/ads_ext/:split_code — the shared Sponster stack (announcer bar +
// ad/tip drawer). Collapsed, the iframe hugs the bottom strip: the widget
// reports its needed height via `sponster_widget_collapsed_height` (50px
// for authed viewers — just the bar; 80px for anonymous viewers — bar plus
// 30px promo-banner/coin headroom). When the LiveView opens its drawer or
// a modal it posts `sponster_widget_expand` / `sponster_widget_collapse`
// messages here and we resize the iframe to full viewport height / back to
// the collapsed height. All drawer/backdrop animation happens inside the
// iframe.
(function () {
  // Anonymous-viewer default until the widget reports its actual height.
  var collapsedHeight = "80px";
  // Matches the drawer slide duration inside the LV so the closing
  // animation finishes before the iframe shrinks and clips it.
  var COLLAPSE_DELAY_MS = 350;

  var widgetDiv = document.getElementById("sponster-tipjar-widget");
  if (!widgetDiv) return;

  var splitCode = widgetDiv.getAttribute("sponster-split-code");
  if (!splitCode) return;

  // Resolve the Qlarius origin from this script's own src so the embed
  // works from any third-party page against whichever host served the
  // script (qadabra.app in production, localhost:4000 in dev). Falls back
  // to the page's own origin, which is only correct for same-origin
  // embeds like the local demosite.
  var qlariusOrigin = (function () {
    var scriptEl =
      document.currentScript ||
      document.querySelector('script[src*="sponster-tipjar-widget-ext-script"]');

    try {
      // `.src` is the DOM property, already resolved to an absolute URL.
      if (scriptEl && scriptEl.src) return new URL(scriptEl.src).origin;
    } catch (_e) {
      // fall through
    }

    return window.location.origin;
  })();

  var widgetSrc =
    qlariusOrigin +
    "/widgets/ads_ext/" +
    encodeURIComponent(splitCode) +
    "?host_url=" +
    encodeURIComponent(document.URL) +
    "&force_theme=light";

  var iframe = document.createElement("iframe");
  iframe.id = "sponster_widget_iframe";
  iframe.src = widgetSrc;
  iframe.setAttribute("frameBorder", "0");
  iframe.setAttribute("allowtransparency", "true");
  iframe.style.cssText = [
    "position: fixed",
    "left: 0",
    "right: 0",
    "bottom: 0",
    "width: 100%",
    "height: " + collapsedHeight,
    "border: 0",
    "background: transparent",
    "z-index: 999999"
  ].join(";");

  widgetDiv.appendChild(iframe);

  var collapseTimer = null;
  var expanded = false;

  function expand() {
    if (collapseTimer) {
      clearTimeout(collapseTimer);
      collapseTimer = null;
    }
    expanded = true;
    iframe.style.height = "100vh";
  }

  function collapse() {
    if (collapseTimer) clearTimeout(collapseTimer);
    expanded = false;
    collapseTimer = setTimeout(function () {
      iframe.style.height = collapsedHeight;
      collapseTimer = null;
    }, COLLAPSE_DELAY_MS);
  }

  window.addEventListener("message", function (e) {
    if (e.origin !== qlariusOrigin) return;

    var type = e.data && e.data.type;

    if (e.source === iframe.contentWindow) {
      if (type === "sponster_widget_expand") expand();
      if (type === "sponster_widget_collapse") collapse();

      // Viewer-dependent collapsed height reported by the widget on mount
      // (50px authed, 80px anon). Apply immediately unless the drawer is
      // currently open.
      if (type === "sponster_widget_collapsed_height" && e.data.height > 0) {
        collapsedHeight = e.data.height + "px";
        if (!expanded && !collapseTimer) iframe.style.height = collapsedHeight;
      }
      return;
    }

    // Sibling Qlarius widget iframes (e.g. the InstaTip card) can ask the
    // host page to open the Sponster drawer; relay into the widget iframe
    // (its SponsterWidgetBridge hook picks it up) and expand right away.
    if (type === "open_sponster_drawer" && iframe.contentWindow) {
      expand();
      iframe.contentWindow.postMessage({ type: "open_sponster_drawer" }, qlariusOrigin);
    }
  });
})();
