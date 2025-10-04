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
          el.classList.remove("ring", "ring-primary", "ring-success", "bg-success", "text-success-content", "ring-error", "bg-error", "text-error-content", "opacity-50")
          void el.offsetWidth // Force reflow

          // Add success colors (transition is preset on element)
          el.classList.add("ring", "ring-success", "bg-success", "text-success-content")

          setTimeout(() => {
            // Remove success styling smoothly
            el.classList.remove("ring", "ring-success", "bg-success", "text-success-content")
          }, 800)
        } else if (value === "delete_fade") {
          // Clear any existing animations
          el.classList.remove("ring", "ring-primary", "ring-success", "bg-success", "text-success-content", "ring-error", "bg-error", "text-error-content", "opacity-50")
          void el.offsetWidth // Force reflow

          // Add error colors (transition is preset on element)
          el.classList.add("ring", "ring-error", "bg-error", "text-error-content")

          // Keep the error styling longer for delete feedback
          setTimeout(() => {
            // Remove error styling smoothly
            el.classList.remove("ring", "ring-error", "bg-error", "text-error-content")
          }, 1200)
        }
      }, delay)
    })
  }
}

function setupCountdown(el, forceReset = false){
  // Always clear existing timer first
  if (el._countdownTimeout) {
    clearTimeout(el._countdownTimeout)
    el._countdownTimeout = null
  }
  
  if (!el) return
  
  // Skip if already initialized and not forcing reset
  if (!forceReset && el.dataset.countdownInitialized === '1') return
  
  const display = el.querySelector('[data-countdown-display]') || el
  const expiresRaw = el.dataset.expiresAt
  const expiresAt = expiresRaw ? Date.parse(expiresRaw) : NaN
  
  if (!display || isNaN(expiresAt)) return

  function update(){
    const now = Date.now()
    const distance = expiresAt - now
    if (distance <= 0){
      display.textContent = 'expired'
      return
    }
    const d = Math.floor(distance / (1000*60*60*24))
    const h = Math.floor((distance % (1000*60*60*24)) / (1000*60*60))
    const m = Math.floor((distance % (1000*60*60)) / (1000*60))
    const s = Math.floor((distance % (1000*60)) / 1000)
    const parts = []
    if (d > 0) parts.push(`${d} ${d===1?'day':'days'}`)
    if (h > 0 || d > 0) parts.push(`${h} ${h===1?'hr':'hrs'}`)
    if (m > 0 || h > 0 || d > 0) parts.push(`${m} ${m===1?'min':'mins'}`)
    if (d < 1 && h < 1) parts.push(`${s} ${s===1?'sec':'secs'}`)
    display.textContent = parts.join(', ')
    el._countdownTimeout = setTimeout(update, 1000)
  }

  el.dataset.countdownInitialized = '1'
  update()
}

function initCountdownTimers(){
  document.querySelectorAll('[data-countdown-root]').forEach(setupCountdown)
}

document.addEventListener('DOMContentLoaded', initCountdownTimers)
window.addEventListener('phx:page-loading-stop', initCountdownTimers)

Hooks.TiqitExpirationCountdown = {
  mounted(){
    setupCountdown(this.el)
  },
  updated(){
    // Force a complete reset with new data
    this.el.dataset.countdownInitialized = '0'
    setupCountdown(this.el, true)
  },
  destroyed(){
    if (this.el && this.el._countdownTimeout) {
      clearTimeout(this.el._countdownTimeout)
      this.el._countdownTimeout = null
    }
  }
}

Hooks.InstaTipHook = {
  mounted() {
    // Listen for Alpine.js events from the InstaTip modal
    this.el.addEventListener('initiate-insta-tip', (event) => {
      const amount = event.detail.amount
      // Send the event to the LiveView to show confirmation modal
      this.pushEvent('initiate_insta_tip', { amount: amount })
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

