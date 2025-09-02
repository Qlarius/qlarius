// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Alpine from "alpinejs"
import {hooks as colocatedHooks} from "phoenix-colocated/qlarius"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}





Hooks.AnimateTrait = {
  mounted() {
    this.handleEvent("animate_trait", ({trait_id, delay_ms, value}) => {
      const delay = typeof delay_ms === "number" ? delay_ms : 250
      setTimeout(() => {
        const el = document.getElementById(`trait-card-${trait_id}`)
        if (!el) return
        // ensure pointer events are re-enabled globally in case a lingering backdrop exists
        document.documentElement.style.pointerEvents = ""
        document.body.style.pointerEvents = ""

        if (value === "update_pulse") {
          // Clear any existing animations
          el.classList.remove("ring", "ring-primary", "ring-success", "scale-105", "bg-success", "text-success-content", "ring-error", "bg-error", "text-error-content", "opacity-50")
          void el.offsetWidth // Force reflow

          // Add success colors, ring and scale up effect with smooth easing
          el.classList.add("ring", "ring-success", "bg-success", "text-success-content", "scale-105", "transition-all", "duration-300", "ease-in-out")

          setTimeout(() => {
            // Scale back down and remove all success styling with smooth easing
            el.classList.remove("ring", "ring-success", "bg-success", "text-success-content", "scale-105")
            el.classList.add("scale-100", "ease-out")

            // Clean up transition classes after animation
            setTimeout(() => {
              el.classList.remove("transition-all", "duration-300", "scale-100", "ease-in-out", "ease-out")
            }, 300)
          }, 800)
        } else if (value === "delete_fade") {
          // Clear any existing animations
          el.classList.remove("ring", "ring-primary", "ring-success", "scale-105", "bg-success", "text-success-content", "ring-error", "bg-error", "text-error-content", "opacity-50", "scale-100")
          void el.offsetWidth // Force reflow

          // Add error colors, ring and scale down effect with fade
          el.classList.add("ring", "ring-error", "bg-error", "text-error-content", "scale-75", "opacity-30", "transition-all", "duration-700", "ease-in-out")

          // Keep the error styling longer for delete feedback
          setTimeout(() => {
            // Fade back to normal but keep the error styling briefly
            el.classList.remove("scale-95", "opacity-50")
            el.classList.add("scale-100", "opacity-100")

            // Clean up transition classes after animation
            setTimeout(() => {
              el.classList.remove("transition-all", "duration-500", "scale-100", "opacity-100", "ease-in-out")
            }, 500)
          }, 1000)
        }
      }, delay)
    })
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  colocatedHooks: colocatedHooks,
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

import "../vendor/nexus.js"

window.Alpine = Alpine
Alpine.start()

// Register service worker for PWA
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js")
  })
}

