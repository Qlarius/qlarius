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

Hooks.TapFeedback = {
  mounted() {
    this.lastPhase = parseInt(this.el.dataset.phase || '0')
    this.phaseChanged = false
    this.minTimeElapsed = true
    this.timer = null
    
    this.handleClick = () => {
      const currentPhase = parseInt(this.el.dataset.phase || '0')
      if (currentPhase < 3) {
        if (this.timer) {
          clearTimeout(this.timer)
        }
        
        this.el.classList.add('ring-4', 'ring-primary')
        this.phaseChanged = false
        this.minTimeElapsed = false
        
        this.timer = setTimeout(() => {
          this.minTimeElapsed = true
          if (this.phaseChanged) {
            this.el.classList.remove('ring-4', 'ring-primary')
          }
          this.timer = null
        }, 300)
      }
    }
    
    this.el.addEventListener('click', this.handleClick)
  },
  
  updated() {
    const newPhase = parseInt(this.el.dataset.phase || '0')
    
    if (newPhase !== this.lastPhase) {
      this.lastPhase = newPhase
      this.phaseChanged = true
    }
    
    if (!this.minTimeElapsed) {
      this.el.classList.add('ring-4', 'ring-primary')
    }
  },
  
  destroyed() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
    if (this.handleClick) {
      this.el.removeEventListener('click', this.handleClick)
    }
  }
}

Hooks.TipDrawerHook = {
  mounted() {
    this.drawerOpen = false
    this.splitAmount = parseInt(this.el.dataset.initialSplit || '50')
    this.currentBalance = parseFloat(this.el.dataset.initialBalance || '0')

    this.drawerEl = document.getElementById('tipjar-drawer')
    this.backdropEl = document.getElementById('tipjar-backdrop')
    this.splitDisplayEl = this.el.querySelector('[data-split-display]')
    this.balanceDisplayEl = this.el.querySelector('[data-balance-display]')
    this.toggleEls = this.el.querySelectorAll('[data-toggle-drawer]')
    this.splitButtons = this.el.querySelectorAll('[data-split]')
    this.instaButtons = this.el.querySelectorAll('[data-instatip]')

    this.toggleDrawer = this.toggleDrawer.bind(this)
    this.recalculatePositions = this.recalculatePositions.bind(this)
    this.applyBottomPosition = this.applyBottomPosition.bind(this)

    document.body.classList.remove('tip-drawer-open')

    this.toggleEls.forEach((el) => el.addEventListener('click', this.toggleDrawer))
    if (this.backdropEl) this.backdropEl.addEventListener('click', this.toggleDrawer)
    this.splitButtons.forEach((btn) => {
      btn.addEventListener('click', () => this.handleSplitClick(parseInt(btn.dataset.split)))
    })
    this.instaButtons.forEach((btn) => {
      btn.addEventListener('click', () => this.handleInstaTipClick(parseFloat(btn.dataset.instatip)))
    })

    window.addEventListener('resize', this.recalculatePositions)
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(() => this.recalculatePositions())
      if (this.drawerEl) this.resizeObserver.observe(this.drawerEl)
    }

    this.handleEvent('update-balance', ({ balance }) => {
      this.updateBalance(balance)
    })

    this.updateSplitDisplay()
    this.updateSplitClasses()
    this.updateInstaButtons()
    this.recalculatePositions()
  },

  toggleDrawer() {
    this.drawerOpen = !this.drawerOpen
    document.body.classList.toggle('tip-drawer-open', this.drawerOpen)
    this.applyBottomPosition()
    if (this.backdropEl) {
      if (this.drawerOpen) {
        this.backdropEl.style.display = 'block'
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            this.backdropEl.classList.remove('opacity-0')
            this.backdropEl.classList.add('opacity-100')
          })
        })
      } else {
        this.backdropEl.classList.remove('opacity-100')
        this.backdropEl.classList.add('opacity-0')
        setTimeout(() => { if (!this.drawerOpen) this.backdropEl.style.display = 'none' }, 300)
      }
    }
  },

  recalculatePositions() {
    if (!this.drawerEl) return
    const drawerHeight = this.drawerEl.offsetHeight
    this.openBottom = 40
    this.closeBottom = (drawerHeight * -1) + 40
    this.applyBottomPosition()
  },

  applyBottomPosition() {
    if (!this.drawerEl) return
    const bottom = this.drawerOpen ? this.openBottom : this.closeBottom
    this.drawerEl.style.bottom = `${bottom}px`
  },

  updateSplitDisplay() {
    if (this.splitDisplayEl) this.splitDisplayEl.textContent = this.splitAmount
  },

  updateSplitClasses() {
    this.splitButtons.forEach((btn) => {
      const pct = parseInt(btn.dataset.split)
      const active = pct === this.splitAmount
      btn.className = active
        ? 'flex-1 px-4 py-2 text-sm font-medium text-white bg-primary focus:outline-none cursor-pointer'
        : 'flex-1 px-4 py-2 text-sm font-medium text-base-content/70 bg-base-100 hover:bg-base-200 focus:outline-none cursor-pointer'
    })
  },

  updateInstaButtons() {
    this.instaButtons.forEach((btn) => {
      const amt = parseFloat(btn.dataset.instatip)
      const enabled = this.currentBalance >= amt
      btn.disabled = !enabled
      btn.className = enabled
        ? 'btn btn-circle btn-primary btn-lg font-bold hover:btn-primary-focus p-8'
        : 'btn btn-circle btn-primary text-sm font-medium btn-disabled p-8'
    })
  },

  updateBalance(newBalance) {
    this.currentBalance = parseFloat(newBalance)
    
    if (this.balanceDisplayEl) {
      this.balanceDisplayEl.textContent = this.formatCurrency(this.currentBalance)
    }
    
    this.updateInstaButtons()
  },

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount)
  },

  handleSplitClick(percentage) {
    this.splitAmount = percentage
    this.updateSplitDisplay()
    this.updateSplitClasses()
    this.pushEvent('set_split', { split: String(percentage) })
  },

  handleInstaTipClick(amount) {
    this.pushEvent('initiate_insta_tip', { amount: amount.toString() })
  },

  destroyed() {
    window.removeEventListener('resize', this.recalculatePositions)
    if (this.resizeObserver) this.resizeObserver.disconnect()
    this.toggleEls && this.toggleEls.forEach((el) => el.removeEventListener('click', this.toggleDrawer))
    if (this.backdropEl) this.backdropEl.removeEventListener('click', this.toggleDrawer)
    this.splitButtons && this.splitButtons.forEach((btn) => btn.replaceWith(btn.cloneNode(true)))
    this.instaButtons && this.instaButtons.forEach((btn) => btn.replaceWith(btn.cloneNode(true)))
  }
}

Hooks.Carousel = {
  mounted() {
    this.intervalMs = parseInt(this.el.dataset.autoplayInterval || '4000')
    this.currentIndex = 1
    this.timer = null
    this.slides = Array.from(this.el.querySelectorAll('[data-slide]'))

    this.showOnly(this.currentIndex)
    this.start()
  },

  updated() {
    this.slides = Array.from(this.el.querySelectorAll('[data-slide]'))
    if (this.currentIndex > this.slides.length) this.currentIndex = 1
    this.showOnly(this.currentIndex)
  },

  destroyed() {
    if (this.timer) clearInterval(this.timer)
  },

  start() {
    if (this.timer) clearInterval(this.timer)
    this.timer = setInterval(() => this.next(), this.intervalMs)
  },

  next() {
    if (this.slides.length === 0) return
    const nextIndex = this.currentIndex < this.slides.length ? this.currentIndex + 1 : 1
    this.fadeTo(nextIndex)
  },

  fadeTo(targetIndex) {
    if (targetIndex === this.currentIndex) return
    const currentEl = this.slides[this.currentIndex - 1]
    const nextEl = this.slides[targetIndex - 1]
    if (!currentEl || !nextEl) return

    currentEl.classList.remove('opacity-100')
    currentEl.classList.add('opacity-0')
    nextEl.classList.remove('opacity-0')
    nextEl.classList.add('opacity-100')
    this.currentIndex = targetIndex
  },

  showOnly(index) {
    this.slides.forEach((el, i) => {
      const active = i === (index - 1)
      el.classList.toggle('opacity-100', active)
      el.classList.toggle('opacity-0', !active)
    })
  }
}

Hooks.PostMessage = {
  mounted() {
    this.handleEvent("send-post-message", (payload) => {
      if (window.parent && window.parent !== window) {
        window.parent.postMessage(payload, '*')
      }
    })
  }
}

Hooks.CurrentMarketer = {
  mounted() {
    const currentMarketerId = localStorage.getItem('current_marketer_id')
    if (currentMarketerId) {
      this.pushEvent('load_current_marketer', { marketer_id: currentMarketerId })
    }

    this.handleEvent('store_current_marketer', ({ marketer_id }) => {
      localStorage.setItem('current_marketer_id', marketer_id)
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

