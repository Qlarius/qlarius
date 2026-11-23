// Demo loader for the publisher-style pages (index.html and the story pages).
//
// KEEP IN SYNC: priv/static/sponster-tipjar-widget-ext-script.js is the
// publisher loader, and priv/static/demosite/local_news/sponster-local.js is
// the local demo copy. When you change iframe injection, postMessage handling,
// or collapsed height here, make the same change in both of those files. The
// only intended difference is the widget origin: this file always uses
// https://qadabra.app. It does not load the script from qadabra.app, because
// the copy deployed there still sends a localhost page to the local widget.
//
// Writes the ad bar iframe and, when present, points #sponster-insta-tip-iframe
// at the production InstaTip widget.
(function () {
  var qlariusOrigin = "https://qadabra.app";

  // Anonymous-viewer default until the widget reports its actual height.
  var collapsedHeight = "80px";
  // Matches the drawer slide duration inside the LV so the closing
  // animation finishes before the iframe shrinks and clips it.
  var COLLAPSE_DELAY_MS = 350;

  var tip = document.getElementById("sponster-insta-tip-iframe");
  if (tip) {
    var tipSplit = tip.getAttribute("data-split-code") || "daily_local";
    tip.src =
      qlariusOrigin + "/widgets/insta_tip?split_code=" + encodeURIComponent(tipSplit);
    window.addEventListener("message", function (event) {
      var data = event.data;
      if (event.source !== tip.contentWindow || !data) return;
      if (data.type === "sponster_tipjar_height" && data.height > 0) {
        tip.style.height = Math.ceil(data.height) + "px";
      }
    });
  }

  var widgetDiv = document.getElementById("sponster-tipjar-widget");
  if (!widgetDiv) return;

  var splitCode = widgetDiv.getAttribute("sponster-split-code");
  if (!splitCode) return;

  // One id per host page, shared by every Qadabra widget iframe on it, so
  // a sign-in in one widget reaches the others even when the browser
  // withholds the widget session cookie.
  var syncId = (function () {
    if (window.__qadabraSyncId) return window.__qadabraSyncId;
    var id;
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      id = window.crypto.randomUUID();
    } else {
      id = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
        var r = (Math.random() * 16) | 0;
        return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
      });
    }
    window.__qadabraSyncId = id;
    return id;
  })();

  var widgetSrc =
    qlariusOrigin +
    "/widgets/ads_ext/" +
    encodeURIComponent(splitCode) +
    "?host_url=" +
    encodeURIComponent(document.URL) +
    "&sync_id=" +
    encodeURIComponent(syncId);

  var forceTheme = widgetDiv.getAttribute("data-force-theme");
  if (forceTheme === "light" || forceTheme === "dark") {
    widgetSrc += "&force_theme=" + encodeURIComponent(forceTheme);
  }

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
    "overflow: hidden",
    "z-index: 999999"
  ].join(";");

  widgetDiv.appendChild(iframe);

  var collapseTimer = null;
  var expanded = false;

  // Presence-only probe for the browser extension (no identity tokens
  // on the publisher page). Nudges the widget iframe when present.
  ;(function probeExtensionPresence() {
    if (typeof chrome === "undefined" || !chrome.runtime || !chrome.runtime.sendMessage) {
      return;
    }

    var idsMeta =
      document.querySelector('meta[name="qadabra-extension-ids"]') &&
      document.querySelector('meta[name="qadabra-extension-ids"]').getAttribute("content");
    // Publisher pages usually lack the meta tag; fall back to known IDs
    // embedded for the production + empty-dev placeholders.
    var ids = (idsMeta || "mhedmgbdabpgflgijpkabcdnkpncbdgp")
      .split(",")
      .map(function (s) {
        return s.trim();
      })
      .filter(function (id) {
        return id && id !== "DEV_EXTENSION_ID_PLACEHOLDER";
      });

    ids.forEach(function (id) {
      try {
        chrome.runtime.sendMessage(id, { type: "qadabra:auth:probe" }, function (response) {
          if (chrome.runtime.lastError || !response || !response.ok) return;
          if (iframe.contentWindow) {
            iframe.contentWindow.postMessage(
              { type: "sponster_extension_present", authed: !!response.authed },
              qlariusOrigin
            );
          }
        });
      } catch (_e) {
        // Extension absent or blocked — leave widget anon.
      }
    });
  })();

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
      // (60px authed, 80px anon). Apply immediately unless the drawer is
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
