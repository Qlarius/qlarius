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
import {hooks as colocatedHooks} from "phoenix-colocated/qlarius"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let Hooks = {}

Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const targetId = this.el.dataset.target
      const targetEl = document.getElementById(targetId)
      
      if (targetEl) {
        targetEl.select()
        targetEl.setSelectionRange(0, 99999)
        
        try {
          const successful = document.execCommand('copy')
          if (successful) {
            this.pushEvent("copy_success", {})
          }
        } catch (err) {
          console.error('Failed to copy: ', err)
        }
      }
    })
  }
}

Hooks.FlashAutoHide = {
  mounted() {
    this.timeout = setTimeout(() => {
      this.el.style.transition = "opacity 300ms ease-in"
      this.el.style.opacity = "0"
      setTimeout(() => {
        this.pushEvent("lv:clear-flash", { key: this.el.dataset.kind })
      }, 300)
    }, 3000)
  },
  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

Hooks.PWAInstall = {
  deferredPrompt: null,

  mounted() {
    this.setupInstallPrompt()
    
    setTimeout(() => {
      this.detectPWAState()
      this.setupInstallButton()
    }, 100)
  },

  detectPWAState() {
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
    const isAndroid = /Android/.test(navigator.userAgent)
    const isPWA = window.matchMedia('(display-mode: standalone)').matches || 
                  window.navigator.standalone === true

    this.pushEvent("check_pwa_state", {
      is_ios: isIOS,
      is_android: isAndroid,
      is_pwa: isPWA
    })

    if (isPWA) {
      this.pushEvent("pwa_installed", {})
    }
  },

  setupInstallPrompt() {
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault()
      this.deferredPrompt = e
      console.log('PWA install prompt available')
    })

    window.addEventListener('appinstalled', () => {
      console.log('PWA installed')
      this.deferredPrompt = null
      this.pushEvent("pwa_installed", {})
    })
  },

  setupInstallButton() {
    const self = this
    
    document.addEventListener('click', function(e) {
      const button = e.target.closest('#trigger-android-install') || 
                     e.target.closest('#android-install-button')
      
      if (button && self.deferredPrompt) {
        e.preventDefault()
        self.deferredPrompt.prompt()
        
        self.deferredPrompt.userChoice.then((choiceResult) => {
          if (choiceResult.outcome === 'accepted') {
            console.log('User accepted the install prompt')
            self.pushEvent("pwa_installed", {})
          } else {
            console.log('User dismissed the install prompt')
          }
          self.deferredPrompt = null
        })
      }
    })
  },

  updated() {
    this.setupInstallButton()
  }
}

Hooks.PWADetect = {
  mounted() {
    setTimeout(() => {
      const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
      const isAndroid = /Android/.test(navigator.userAgent)
      const isPWA = window.matchMedia('(display-mode: standalone)').matches || 
                    window.navigator.standalone === true
      const inIframe = window.self !== window.top

      let deviceType = 'mobile_phone'
      if (isIOS) {
        deviceType = 'ios_phone'
      } else if (isAndroid) {
        deviceType = 'android_phone'
      } else if (!isIOS && !isAndroid) {
        deviceType = 'desktop'
      }

      const isMobile = isIOS || isAndroid

      console.log('[PWA Detection]', {
        isPWA,
        isIOS,
        isAndroid,
        deviceType,
        matchMedia: window.matchMedia('(display-mode: standalone)').matches,
        standalone: window.navigator.standalone,
        safeAreaTop: getComputedStyle(document.documentElement).getPropertyValue('env(safe-area-inset-top)'),
        safeAreaBottom: getComputedStyle(document.documentElement).getPropertyValue('env(safe-area-inset-bottom)')
      })

      // Store PWA status in cookie for server-side access on first render
      // This prevents layout flash by allowing server to read PWA status before mount
      try {
        document.cookie = `is_pwa=${isPWA}; path=/; max-age=31536000; SameSite=Lax`
        console.log('[PWA Detection] Stored in cookie:', { isPWA, deviceType })
      } catch (e) {
        console.warn('[PWA Detection] Could not store in cookie:', e)
      }

      // iOS 18+ fix: env() safe area insets don't work properly in PWAs
      // Use JavaScript to apply safe area padding dynamically
      if (isPWA && isIOS) {
        this.applySafeAreaFix()
      }

      this.pushEvent("pwa_detected", {
        is_pwa: isPWA,
        in_iframe: inIframe,
        is_mobile: isMobile,
        device_type: deviceType
      })
    }, 100)
  },
  
  applySafeAreaFix() {
    // iOS 18+ PWAs automatically handle safe area spacing
    // Set to 0 to let iOS handle it natively
    let bottomInset = 0
    
    console.log('[Safe Area Fix]', {
      bottomInset: bottomInset,
      message: 'Disabled - letting iOS handle safe area natively'
    })
    
    // Apply custom CSS variable (set to 0)
    document.documentElement.style.setProperty('--safe-area-inset-bottom-js', `${bottomInset}px`)
  }
}

Hooks.HiPagePWADetect = Hooks.PWADetect

Hooks.HiPageSplash = {
  mounted() {
    setTimeout(() => {
      this.pushEvent("splash_complete", {})
    }, 2000)
  }
}

Hooks.CarouselIndicators = {
  mounted() {
    const carousel = this.el.querySelector('.carousel')
    const indicators = this.el.querySelectorAll('.carousel-indicator')
    
    if (!carousel || indicators.length === 0) return

    const calculatePagination = () => {
      const carouselWidth = carousel.offsetWidth
      const firstCard = carousel.querySelector('.carousel-item')
      if (!firstCard) return { pages: 1, cardsPerPage: 1 }
      
      const cardWidth = firstCard.offsetWidth
      const gap = 16
      const cardsPerPage = Math.max(1, Math.floor(carouselWidth / (cardWidth + gap)))
      const totalCards = carousel.querySelectorAll('.carousel-item').length
      const pages = Math.ceil(totalCards / cardsPerPage)
      
      return { pages, cardsPerPage, cardWidth, gap, totalCards }
    }

    const updateIndicators = () => {
      const { pages, cardsPerPage, cardWidth, gap, totalCards } = calculatePagination()
      const scrollLeft = carousel.scrollLeft
      const maxScroll = carousel.scrollWidth - carousel.offsetWidth
      
      // Calculate current page based on scroll position
      let currentPage = 0
      if (maxScroll > 0) {
        const scrollProgress = scrollLeft / maxScroll
        currentPage = Math.min(pages - 1, Math.floor(scrollProgress * pages))
      }
      
      // Hide entire indicator container if only one page
      const indicatorContainer = indicators[0]?.parentElement
      if (indicatorContainer) {
        if (pages <= 1) {
          indicatorContainer.style.display = 'none'
        } else {
          indicatorContainer.style.display = 'flex'
        }
      }
      
      // Show/hide individual indicators based on number of pages
      indicators.forEach((indicator, index) => {
        if (index < pages) {
          indicator.style.display = 'block'
          
          if (index === currentPage) {
            indicator.classList.remove('bg-base-content/30')
            indicator.classList.add('bg-primary', 'w-6')
          } else {
            indicator.classList.remove('bg-primary', 'w-6')
            indicator.classList.add('bg-base-content/30')
          }
        } else {
          indicator.style.display = 'none'
        }
      })
    }

    // Update on scroll
    carousel.addEventListener('scroll', updateIndicators)
    
    // Update on window resize
    let resizeTimeout
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimeout)
      resizeTimeout = setTimeout(updateIndicators, 100)
    })
    
    // Initial update
    setTimeout(updateIndicators, 100)
    
    this.handleEvent = () => {
      updateIndicators()
    }
  }
}

Hooks.AdminSidebar = {
  mounted() {
    const sectionIds = ['sidebar-consumer', 'sidebar-marketer', 'sidebar-creator', 'sidebar-admin']
    
    // Restore checkbox states IMMEDIATELY (synchronously)
    sectionIds.forEach(id => {
      const checkbox = document.getElementById(id)
      if (checkbox) {
        const savedState = localStorage.getItem(`admin_sidebar_${id}`)
        if (savedState !== null) {
          checkbox.checked = savedState === 'true'
        }
        
        // Save on change
        checkbox.addEventListener('change', () => {
          localStorage.setItem(`admin_sidebar_${id}`, checkbox.checked)
        })
      }
    })
    
    // Restore scroll position
    const restoreScroll = () => {
      // Try to find SimpleBar's scroll container first
      const scrollContainer = this.el.querySelector('.simplebar-content-wrapper') || this.el
      const savedScrollPosition = localStorage.getItem('admin_sidebar_scroll')
      
      if (savedScrollPosition && scrollContainer) {
        const scrollPos = parseInt(savedScrollPosition, 10)
        scrollContainer.scrollTop = scrollPos
        
        // Force a reflow to ensure it takes
        void scrollContainer.offsetHeight
      }
    }
    
    // Restore immediately and then again after render
    restoreScroll()
    requestAnimationFrame(() => {
      restoreScroll()
      requestAnimationFrame(restoreScroll)
    })
    
    // Save scroll position on scroll (with debounce)
    this.scrollTimeout = null
    this.scrollHandler = () => {
      if (this.scrollTimeout) clearTimeout(this.scrollTimeout)
      
      this.scrollTimeout = setTimeout(() => {
        const scrollContainer = this.el.querySelector('.simplebar-content-wrapper') || this.el
        if (scrollContainer) {
          localStorage.setItem('admin_sidebar_scroll', scrollContainer.scrollTop)
        }
      }, 150)
    }
    
    // Attach scroll listener
    const simplebarWrapper = this.el.querySelector('.simplebar-content-wrapper')
    if (simplebarWrapper) {
      simplebarWrapper.addEventListener('scroll', this.scrollHandler, { passive: true })
    } else {
      this.el.addEventListener('scroll', this.scrollHandler, { passive: true })
    }
  },
  
  destroyed() {
    if (this.scrollTimeout) {
      clearTimeout(this.scrollTimeout)
    }
    if (this.scrollHandler) {
      const simplebarWrapper = this.el.querySelector('.simplebar-content-wrapper')
      if (simplebarWrapper) {
        simplebarWrapper.removeEventListener('scroll', this.scrollHandler)
      } else {
        this.el.removeEventListener('scroll', this.scrollHandler)
      }
    }
  }
}





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
        this.backdropEl.classList.remove('pointer-events-none')
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            this.backdropEl.classList.remove('opacity-0')
            this.backdropEl.classList.add('opacity-100')
          })
        })
      } else {
        this.backdropEl.classList.remove('opacity-100')
        this.backdropEl.classList.add('opacity-0')
        setTimeout(() => { 
          if (!this.drawerOpen) this.backdropEl.classList.add('pointer-events-none')
        }, 300)
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
    this.handleEvent('store_current_marketer', async ({ marketer_id }) => {
      localStorage.setItem('current_marketer_id', marketer_id)

      // Also store in Phoenix session for controller access
      const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      await fetch('/marketer/set_current_marketer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ marketer_id })
      })
    })
  }
}

Hooks.ZipSelector = {
  mounted() {
    this.availableSelect = this.el.querySelector('#available-zips')
    this.selectedSelect = this.el.querySelector('#selected-zips')
    
    this.el.querySelectorAll('[data-action]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const action = e.target.dataset.action || e.target.closest('[data-action]')?.dataset.action
        
        if (action === 'add-all') {
          this.pushEvent('add_all_visible_zips', {})
        } else if (action === 'add-selected') {
          const selectedIds = Array.from(this.availableSelect.selectedOptions)
            .filter(opt => !opt.disabled)
            .map(opt => opt.value)
          if (selectedIds.length > 0) {
            this.pushEvent('add_selected_zips', { selected_ids: selectedIds })
          }
        } else if (action === 'remove-selected') {
          const selectedIds = Array.from(this.selectedSelect.selectedOptions).map(opt => opt.value)
          if (selectedIds.length > 0) {
            this.pushEvent('remove_selected_zips', { selected_ids: selectedIds })
          }
        } else if (action === 'clear-all') {
          this.pushEvent('clear_all_zips', {})
        }
      })
    })
  }
}

Hooks.TaggerButtonObserver = {
  mounted() {
    this.floatingBtn = document.getElementById('floating-tagger-btn')
    
    if (!this.floatingBtn) return
    
    // Find the scroll container (either .panel-scroll for dual-pane or viewport for single-pane)
    const scrollContainer = this.el.closest('.panel-scroll')
    
    const options = {
      root: scrollContainer,
      rootMargin: '0px 0px -120px 0px', // Trigger 20px sooner (was -80px, now -100px)
      threshold: 0
    }
    
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Inline button is visible, hide floating button
          this.floatingBtn.classList.add('opacity-0', 'pointer-events-none')
        } else {
          // Inline button is out of view (below dock), show floating button
          this.floatingBtn.classList.remove('opacity-0', 'pointer-events-none')
        }
      })
    }, options)
    
    this.observer.observe(this.el)
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

Hooks.VideoPlayer = {
  mounted() {
    this.video = this.el
    this.watched = false
    this.paymentCollected = this.el.dataset.paymentCollected === 'true'
    this.lastValidTime = 0
    
    // Detect if running in PWA mode and device type
    const isPWA = window.matchMedia('(display-mode: standalone)').matches || 
                  window.navigator.standalone === true
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
    const isAndroid = /Android/.test(navigator.userAgent)
    
    // Prevent seeking forward on paid viewing (before collection)
    if (!this.paymentCollected) {
      this.video.addEventListener('timeupdate', () => {
        // Allow some tolerance for buffering (0.5 seconds)
        if (!this.watched && this.video.currentTime > this.lastValidTime + 0.5) {
          // User tried to skip forward - reset to last valid position
          this.video.currentTime = this.lastValidTime
        } else if (this.video.currentTime <= this.lastValidTime + 0.5) {
          // Update last valid time (user is watching normally or seeking backward)
          this.lastValidTime = this.video.currentTime
        }
      })
      
      // Prevent seeking via keyboard or other methods
      this.video.addEventListener('seeking', () => {
        if (!this.watched && this.video.currentTime > this.lastValidTime + 0.5) {
          this.video.currentTime = this.lastValidTime
        }
      })
    }
    
    // Request fullscreen on play for Android PWAs
    // iOS Safari automatically goes fullscreen by default without playsinline attribute
    if (isPWA && isAndroid) {
      this.video.addEventListener('play', () => {
        if (this.video.requestFullscreen) {
          this.video.requestFullscreen().catch(err => {
            console.log('Fullscreen request failed:', err)
          })
        } else if (this.video.webkitRequestFullscreen) {
          this.video.webkitRequestFullscreen().catch(err => {
            console.log('Webkit fullscreen request failed:', err)
          })
        }
      }, { once: true })
    }
    
    this.video.play().catch(err => {
      console.log('Autoplay prevented:', err)
    })
    
    this.video.addEventListener('ended', () => {
      if (!this.watched) {
        this.watched = true
        this.pushEvent('video_watched_complete', {})
      }
      
      // Exit fullscreen when video completes
      // iOS uses webkitExitFullscreen on the video element itself
      if (this.video.webkitDisplayingFullscreen) {
        this.video.webkitExitFullscreen()
      } else if (document.fullscreenElement) {
        document.exitFullscreen()
      } else if (document.webkitFullscreenElement) {
        document.webkitExitFullscreen()
      }
    })
    
    this.handleEvent('replay-video', () => {
      this.video.currentTime = 0
      this.watched = false
      this.video.play()
    })
  },
  
  updated() {
    // Update payment status when component re-renders
    this.paymentCollected = this.el.dataset.paymentCollected === 'true'
  }
}

Hooks.SlideToCollect = {
  mounted() {
    console.log('=== SLIDE TO COLLECT MOUNTED ===')
    this.offerId = this.el.dataset.offerId
    this.amount = this.el.dataset.amount
    console.log('Offer ID:', this.offerId)
    console.log('Amount:', this.amount)
    
    this.countdown = 7
    this.countdownTimer = null
    this.isDragging = false
    this.startX = 0
    this.currentX = 0
    this.completed = false
    
    this.handle = document.getElementById(`${this.el.id}-handle`)
    this.slider = document.getElementById(`${this.el.id}-slider`)
    this.countdownEl = document.getElementById(`${this.el.id}-countdown`)
    this.progressBar = document.getElementById(`${this.el.id}-progress`)
    
    console.log('Elements found:', {
      handle: !!this.handle,
      slider: !!this.slider,
      countdownEl: !!this.countdownEl,
      progressBar: !!this.progressBar
    })
    
    if (!this.handle || !this.slider) {
      console.error('Missing required elements!')
      return
    }
    
    this.sliderWidth = this.slider.offsetWidth
    this.handleWidth = this.handle.offsetWidth
    this.maxDistance = this.sliderWidth - this.handleWidth - 8
    
    console.log('Slider dimensions:', {
      sliderWidth: this.sliderWidth,
      handleWidth: this.handleWidth,
      maxDistance: this.maxDistance
    })
    
    this.startCountdown()
    this.setupDrag()
  },
  
  startCountdown() {
    this.countdownTimer = setInterval(() => {
      if (this.completed) {
        clearInterval(this.countdownTimer)
        return
      }
      
      this.countdown--
      if (this.countdownEl) {
        this.countdownEl.textContent = this.countdown
      }
      
      const progressPercent = ((7 - this.countdown) / 7) * 100
      if (this.progressBar) {
        this.progressBar.style.width = `${progressPercent}%`
      }
      
      if (this.countdown <= 0) {
        clearInterval(this.countdownTimer)
        this.pushEvent('video_collect_timeout', {})
      }
    }, 1000)
  },
  
  setupDrag() {
    const handleMouseDown = (e) => {
      this.isDragging = true
      this.startX = e.type === 'mousedown' ? e.clientX : e.touches[0].clientX
      this.handle.style.transition = 'none'
      this.handle.classList.remove('wiggle')
      e.preventDefault()
    }
    
    const handleMouseMove = (e) => {
      if (!this.isDragging || this.completed) return
      
      const clientX = e.type === 'mousemove' ? e.clientX : e.touches[0].clientX
      const deltaX = clientX - this.startX
      this.currentX = Math.max(0, Math.min(deltaX, this.maxDistance))
      
      this.handle.style.transform = `translateX(${this.currentX}px) translateY(-50%)`
      
      if (this.currentX >= this.maxDistance * 0.9) {
        this.completeSlide()
      }
    }
    
    const handleMouseUp = () => {
      if (!this.isDragging) return
      
      this.isDragging = false
      this.handle.style.transition = 'transform 0.3s ease'
      this.handle.style.transform = 'translateX(0) translateY(-50%)'
      
      if (!this.completed) {
        this.handle.classList.add('wiggle')
      }
      
      this.currentX = 0
    }
    
    this.handle.addEventListener('mousedown', handleMouseDown)
    this.handle.addEventListener('touchstart', handleMouseDown, { passive: false })
    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('touchmove', handleMouseMove, { passive: false })
    document.addEventListener('mouseup', handleMouseUp)
    document.addEventListener('touchend', handleMouseUp)
    
    this.cleanupListeners = () => {
      this.handle.removeEventListener('mousedown', handleMouseDown)
      this.handle.removeEventListener('touchstart', handleMouseDown)
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('touchmove', handleMouseMove)
      document.removeEventListener('mouseup', handleMouseUp)
      document.removeEventListener('touchend', handleMouseUp)
    }
  },
  
  completeSlide() {
    if (this.completed) {
      console.log('Already completed, skipping...')
      return
    }
    
    console.log('=== SLIDE COMPLETED ===')
    console.log('Offer ID:', this.offerId)
    
    this.completed = true
    this.handle.classList.remove('wiggle')
    
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
    }
    
    console.log('Pushing collect_video_payment event...')
    this.pushEvent('collect_video_payment', { offer_id: this.offerId })
  },
  
  destroyed() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
    }
    if (this.cleanupListeners) {
      this.cleanupListeners()
    }
  }
}

// Handle focus events from LiveView
window.addEventListener("phx:focus", (e) => {
  const el = document.getElementById(e.detail.id)
  if (el) {
    // Small delay to ensure DOM is updated
    setTimeout(() => {
      el.focus()
      el.select()
    }, 100)
  }
})

// Handle scroll-to-top for tag list modal
window.addEventListener("phx:scroll-tag-list-to-top", () => {
  const container = document.getElementById("tag-list-scroll-container")
  if (container) {
    container.scrollTop = 0
  }
})

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => ({
    _csrf_token: csrfToken,
    current_marketer_id: localStorage.getItem('current_marketer_id')
  }),
  colocatedHooks: colocatedHooks,
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle modal close events from server
window.addEventListener("phx:close-modal", (e) => {
  const modalId = e.detail.id
  const modal = document.getElementById(modalId)
  if (modal) {
    const event = new Event("phx-remove", { bubbles: true })
    modal.dispatchEvent(event)
  }
})

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

Hooks.PushNotifications = {
  mounted() {
    this.checkCurrentDeviceSubscription()
    
    this.handleEvent("request-push-permission", async () => {
      console.log("📢 Request push permission event received")
      await this.requestPermission()
    })
  },

  async checkCurrentDeviceSubscription() {
    if (!("Notification" in window) || !("serviceWorker" in navigator) || !("PushManager" in window)) {
      console.log("Push notifications not supported on this device")
      this.pushEvent("device_not_subscribed", { supported: false })
      return
    }

    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()
      
      const permission = Notification.permission
      console.log("Current notification permission:", permission)
      console.log("Current device subscription:", subscription ? "EXISTS" : "NONE")
      
      if (subscription && permission === "granted") {
        console.log("✅ This device is subscribed to push notifications")
        this.pushEvent("device_subscribed", { 
          endpoint: subscription.endpoint,
          subscribed: true 
        })
      } else {
        console.log("❌ This device is NOT subscribed to push notifications")
        this.pushEvent("device_not_subscribed", { 
          supported: true,
          permission: permission 
        })
      }
    } catch (error) {
      console.error("Error checking subscription:", error)
      this.pushEvent("device_not_subscribed", { supported: true })
    }
  },

  async requestPermission() {
    console.log("🔔 Requesting notification permission...")
    const permission = await Notification.requestPermission()
    console.log("📢 Permission result:", permission)
    
    if (permission === "granted") {
      console.log("✅ Permission granted, subscribing to push...")
      await this.subscribeToPush()
      this.pushEvent("permission_granted", {})
    } else {
      console.log("❌ Permission denied")
      this.pushEvent("permission_denied", {})
    }
  },

  async subscribeToPush() {
    try {
      console.log("🔄 Starting push subscription...")
      const registration = await navigator.serviceWorker.ready
      console.log("✅ Service worker ready")
      
      console.log("🔑 Fetching VAPID public key...")
      const response = await fetch("/api/push/vapid-public-key", {
        headers: {
          "x-csrf-token": document.querySelector("meta[name='csrf-token']").content
        }
      })
      const { publicKey } = await response.json()
      console.log("✅ Got VAPID public key:", publicKey.substring(0, 20) + "...")
      
      console.log("📝 Subscribing to push manager...")
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(publicKey)
      })
      console.log("✅ Push manager subscription successful!")

      const saveResponse = await fetch("/api/push/subscribe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-csrf-token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({
          subscription: subscription.toJSON(),
          device_type: this.detectBrowser(),
          user_agent: navigator.userAgent
        })
      })

      console.log("💾 Subscription object:", subscription)

      if (saveResponse.ok) {
        console.log("✅ Subscribed to push notifications")
        this.pushEvent("device_subscribed", { 
          endpoint: subscription.endpoint,
          subscribed: true 
        })
      } else {
        const errorText = await saveResponse.text()
        console.error("❌ Failed to save subscription to server:", errorText)
        this.pushEvent("subscription_failed", { error: `Server error: ${errorText}` })
      }
    } catch (error) {
      console.error("❌ Failed to subscribe to push:", error)
      console.error("Error name:", error.name)
      console.error("Error message:", error.message)
      console.error("Error stack:", error.stack)
      this.pushEvent("subscription_failed", { error: error.message || error.toString() })
    }
  },

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding)
      .replace(/\-/g, "+")
      .replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  },

  detectBrowser() {
    const userAgent = navigator.userAgent
    if (userAgent.includes("Firefox")) return "firefox"
    if (userAgent.includes("Chrome")) return "chrome"
    if (userAgent.includes("Safari")) return "safari"
    if (userAgent.includes("Edge")) return "edge"
    return "other"
  }
}

window.addEventListener("push-request-permission", () => {
  const hook = Hooks.PushNotifications
  if (hook && hook.requestPermission) {
    hook.requestPermission()
  }
})

Hooks.TimezoneDetector = {
  mounted() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    console.log("🌍 Detected timezone:", timezone)
    this.pushEvent("timezone_detected", { timezone })
  }
}

// Register service worker for PWA
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js")
      .then(registration => {
        console.log("✅ Service Worker registered:", registration.scope)
      })
      .catch(error => {
        console.error("❌ Service Worker registration failed:", error)
      })
  })
} else {
  console.warn("❌ Service Worker not supported in this browser")
}

