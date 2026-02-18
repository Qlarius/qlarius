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

// iOS Audio Priming - unlock audio playback on first user interaction
// iOS Safari requires audio to be triggered by user gesture before programmatic playback works
// This global listener ensures audio is unlocked regardless of where user first interacts
function primeAudioForIOS() {
  if (window.walletAudioUnlocked) return
  
  // Create the shared audio object if it doesn't exist
  if (!window.walletCoinSound) {
    window.walletCoinSound = new Audio('/sounds/coin-clink.wav')
    window.walletCoinSound.volume = 0.5
  }
  
  const sound = window.walletCoinSound
  const originalVolume = sound.volume
  sound.volume = 0
  sound.currentTime = 0
  sound.play().then(() => {
    sound.pause()
    sound.currentTime = 0
    sound.volume = originalVolume
    window.walletAudioUnlocked = true
  }).catch(() => {
    sound.volume = originalVolume
  })
}

// Prime audio on first click or touch anywhere on the page
document.addEventListener('click', primeAudioForIOS, { once: true })
document.addEventListener('touchstart', primeAudioForIOS, { once: true })

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
  },
  
  applyViewportFix() {
    // iOS PWA viewport bug: 100dvh isn't calculated correctly on initial load
    // Fix: Set a CSS variable with the actual viewport height from JavaScript
    const setViewportHeight = () => {
      const vh = window.innerHeight
      document.documentElement.style.setProperty('--app-height', `${vh}px`)
      console.log('[Viewport Fix] Set --app-height to', vh)
    }
    
    // Set immediately
    setViewportHeight()
    
    // Also set on resize (orientation change, etc)
    window.addEventListener('resize', setViewportHeight)
    
    // And after a short delay to catch any late layout shifts
    setTimeout(setViewportHeight, 100)
    setTimeout(setViewportHeight, 500)
  }
}

// HiPagePWADetect - extends PWADetect to also capture referral code from URL
Hooks.HiPagePWADetect = {
  mounted() {
    const REFERRAL_ENDPOINT = '/_shared/referral-code'
    
    // Capture referral code from URL and store everywhere
    const urlParams = new URLSearchParams(window.location.search)
    const refCodeFromUrl = urlParams.get('ref') || urlParams.get('invite')
    
    if (refCodeFromUrl) {
      // Set cookie that expires in 30 days
      const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toUTCString()
      document.cookie = `qadabra_referral_code=${encodeURIComponent(refCodeFromUrl)}; expires=${expires}; path=/; SameSite=Lax`
      // Store in localStorage
      try { localStorage.setItem('qadabra_referral_code', refCodeFromUrl) } catch (e) {}
      // Store in Cache Storage via service worker (SHARED on iOS!)
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.ready.then(() => {
          fetch(REFERRAL_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ referral_code: refCodeFromUrl })
          }).catch(() => {})
        })
      }
      console.log('🎯 Referral code captured:', refCodeFromUrl)
    }
    
    // Get referral code (from URL or localStorage)
    let refCode = refCodeFromUrl || this.getStoredReferralCode()
    
    // If we have a code, push to LiveView
    if (refCode) {
      this.pushReferralToLiveView(refCode)
    } else {
      // Try to get from Cache Storage (for iOS PWA case)
      this.tryLoadFromCacheStorage()
    }
    
    // Also listen for the event from root script's Cache Storage load
    window.addEventListener('referral-code-loaded', (e) => {
      if (e.detail && !this.referralPushed) {
        console.log('🎯 Got referral from Cache Storage event:', e.detail)
        this.pushReferralToLiveView(e.detail)
      }
    }, { once: true })
    
    // Run PWA detection
    Hooks.PWADetect.mounted.call(this)
  },
  
  referralPushed: false,
  
  pushReferralToLiveView(code) {
    if (this.referralPushed) return
    this.referralPushed = true
    setTimeout(() => {
      console.log('🎯 Pushing referral code to LiveView:', code)
      this.pushEvent("referral_code_from_storage", { code: code })
    }, 100)
  },
  
  tryLoadFromCacheStorage() {
    const REFERRAL_ENDPOINT = '/_shared/referral-code'
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then(() => {
        fetch(REFERRAL_ENDPOINT).then(r => r.json()).then(data => {
          if (data.referral_code && !this.referralPushed) {
            console.log('🎯 Loaded referral from Cache Storage:', data.referral_code)
            try { localStorage.setItem('qadabra_referral_code', data.referral_code) } catch (e) {}
            this.pushReferralToLiveView(data.referral_code)
          }
        }).catch(() => {})
      })
    }
  },
  
  getStoredReferralCode() {
    try {
      const lsCode = localStorage.getItem('qadabra_referral_code')
      if (lsCode) return lsCode
    } catch (e) {}
    
    const cookies = document.cookie.split(';').reduce((acc, cookie) => {
      const [key, value] = cookie.trim().split('=')
      if (key && value) acc[key] = decodeURIComponent(value)
      return acc
    }, {})
    return cookies['qadabra_referral_code'] || null
  },
  
  applySafeAreaFix: Hooks.PWADetect.applySafeAreaFix,
  applyViewportFix: Hooks.PWADetect.applyViewportFix
}

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
        // Prime audio for iOS - must happen during user gesture to unlock audio playback
        // This allows the WalletPulse hook to play sounds when balance updates via WebSocket
        this.primeAudioForIOS()
        
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
  
  primeAudioForIOS() {
    // iOS requires audio to be triggered by user gesture before programmatic playback works
    // We play the sound silently to "unlock" the audio context
    if (!window.walletCoinSound) {
      window.walletCoinSound = new Audio('/sounds/coin-clink.wav')
      window.walletCoinSound.volume = 0.5
    }
    
    // Only prime if not already unlocked this session
    if (!window.walletAudioUnlocked) {
      const sound = window.walletCoinSound
      const originalVolume = sound.volume
      sound.volume = 0
      sound.currentTime = 0
      sound.play().then(() => {
        sound.pause()
        sound.currentTime = 0
        sound.volume = originalVolume
        window.walletAudioUnlocked = true
      }).catch(() => {
        // Ignore errors - audio may already be unlocked or not available
        sound.volume = originalVolume
      })
    }
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
      const disclaimerEl = document.getElementById('ads-disclaimer-bar')
      if (disclaimerEl) this.resizeObserver.observe(disclaimerEl)
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
    if (this.drawerOpen) {
      this.pushEvent('split_drawer_opened', {})
    }
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
    const disclaimerEl = document.getElementById('ads-disclaimer-bar')
    const offset = disclaimerEl ? disclaimerEl.offsetHeight : 40
    this.openBottom = offset
    this.closeBottom = (drawerHeight * -1) + offset
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
      rootMargin: '0px 0px -80px 0px', // Account for nav bar height
      threshold: 0
    }
    
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Inline button is visible, hide floating button
          this.floatingBtn.classList.add('opacity-0', 'pointer-events-none')
        } else {
          // Inline button is out of view (below nav bar), show floating button
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

Hooks.FadeIn = {
  mounted() {
    // Set up transition
    this.el.style.transition = 'opacity 0.5s ease-in-out'
    
    // Trigger fade-in after a brief delay to ensure DOM is ready
    setTimeout(() => {
      this.el.style.opacity = '1'
    }, 100)
  }
  // No updated() callback - fade only happens once on mount
}

Hooks.VideoThumbnail = {
  mounted() {
    this.video = this.el
    this.thumbnailId = this.el.dataset.thumbnailId
    
    if (!this.thumbnailId) return
    
    this.posterEl = document.getElementById(`${this.thumbnailId}-poster`)
    this.videoContainer = document.getElementById(`${this.thumbnailId}-video`)
    
    this.playHandler = () => {
      this.video.play().catch(err => {
        console.log('Autoplay prevented:', err)
      })
    }
    
    this.video.addEventListener('video-thumbnail-play', this.playHandler)
    
    this.endedHandler = () => {
      if (this.posterEl && this.videoContainer) {
        this.video.pause()
        this.video.currentTime = 0
        
        this.videoContainer.classList.add('hidden')
        this.videoContainer.style.display = 'none'
        
        this.posterEl.classList.remove('hidden')
        this.posterEl.style.display = ''
      }
    }
    
    this.video.addEventListener('ended', this.endedHandler)
  },
  
  destroyed() {
    if (this.playHandler) {
      this.video.removeEventListener('video-thumbnail-play', this.playHandler)
    }
    if (this.endedHandler) {
      this.video.removeEventListener('ended', this.endedHandler)
    }
  }
}

Hooks.VideoPlayer = {
  mounted() {
    this.video = this.el
    this.watched = false
    this.paymentCollected = this.el.dataset.paymentCollected === 'true'
    this.isReplay = this.el.dataset.isReplay === 'true'
    this.watchedOnce = this.paymentCollected
    this.lastValidTime = 0
    this.isFirstPlay = true
    
    const isPWA = window.matchMedia('(display-mode: standalone)').matches || 
                  window.navigator.standalone === true
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
    const isAndroid = /Android/.test(navigator.userAgent)
    
    // Prevent seeking forward only on initial unpaid viewing (before first completion)
    if (!this.paymentCollected) {
      this.video.addEventListener('timeupdate', () => {
        if (!this.watchedOnce && this.video.currentTime > this.lastValidTime + 0.5) {
          this.video.currentTime = this.lastValidTime
        } else if (this.video.currentTime <= this.lastValidTime + 0.5) {
          this.lastValidTime = this.video.currentTime
        }
      })
      
      this.video.addEventListener('seeking', () => {
        if (!this.watchedOnce && this.video.currentTime > this.lastValidTime + 0.5) {
          this.video.currentTime = this.lastValidTime
        }
      })
    }
    
    // Request fullscreen on play for Android PWAs
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
    
    // Start countdown on first play (not replay)
    if (!this.isReplay) {
      setTimeout(() => this.startCountdown(), 100)
    } else {
      setTimeout(() => this.showPlayIcon(), 100)
    }
    
    this.video.addEventListener('ended', () => {
      if (!this.watched) {
        this.watched = true
        this.watchedOnce = true
        this.pushEvent('video_watched_complete', {})
      }
      
      // Exit fullscreen
      if (this.video.webkitDisplayingFullscreen) {
        this.video.webkitExitFullscreen()
      } else if (document.fullscreenElement) {
        document.exitFullscreen()
      } else if (document.webkitFullscreenElement) {
        document.webkitExitFullscreen()
      }
      
      // Show poster overlay with play icon
      this.showPosterWithPlayIcon()
    })
    
    this.handleEvent('replay-video', () => {
      this.video.currentTime = 0
      this.watched = false
      this.hidePosterAndPlay()
    })
  },
  
  startCountdown() {
    const countdownNumber = document.getElementById('video-countdown-number')
    const playIcon = document.getElementById('video-play-icon')
    
    if (!countdownNumber) {
      this.hidePosterAndPlay()
      return
    }
    
    let count = 3
    countdownNumber.textContent = count
    countdownNumber.classList.remove('hidden')
    if (playIcon) {
      playIcon.classList.add('hidden')
    }
    
    setTimeout(() => {
      const countdownInterval = setInterval(() => {
        count--
        if (count > 0) {
          countdownNumber.textContent = count
        } else {
          clearInterval(countdownInterval)
          this.countdownInterval = null
          this.hidePosterAndPlay()
        }
      }, 1000)
      
      this.countdownInterval = countdownInterval
    }, 100)
  },
  
  hidePosterAndPlay() {
    const posterOverlay = document.getElementById('video-poster-overlay')
    if (posterOverlay) {
      posterOverlay.style.display = 'none'
      posterOverlay.classList.add('pointer-events-none')
    }
    
    this.video.play().catch(() => {})
  },
  
  showPosterWithPlayIcon() {
    const posterOverlay = document.getElementById('video-poster-overlay')
    if (posterOverlay) {
      posterOverlay.style.display = ''
      posterOverlay.classList.remove('pointer-events-none')
    }
    this.showPlayIcon()
  },
  
  showPlayIcon() {
    const countdownNumber = document.getElementById('video-countdown-number')
    const playIcon = document.getElementById('video-play-icon')
    
    if (countdownNumber) {
      countdownNumber.classList.add('hidden')
      countdownNumber.textContent = ''
    }
    if (playIcon) {
      playIcon.classList.remove('hidden')
    }
  },
  
  updated() {
    this.paymentCollected = this.el.dataset.paymentCollected === 'true'
    this.isReplay = this.el.dataset.isReplay === 'true'
  },
  
  destroyed() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
    }
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
    this.checkmark = document.getElementById(`${this.el.id}-checkmark`)
    this.handleArrow = document.getElementById(`${this.el.id}-handle-arrow`)
    this.handleAmount = document.getElementById(`${this.el.id}-handle-amount`)
    this.destination = document.getElementById(`${this.el.id}-destination`)
    this.message = document.getElementById(`${this.el.id}-message`)
    
    console.log('Elements found:', {
      handle: !!this.handle,
      slider: !!this.slider,
      countdownEl: !!this.countdownEl,
      progressBar: !!this.progressBar,
      checkmark: !!this.checkmark,
      handleArrow: !!this.handleArrow,
      handleAmount: !!this.handleAmount,
      destination: !!this.destination,
      message: !!this.message
    })
    
    if (!this.handle || !this.slider) {
      console.error('Missing required elements!')
      return
    }
    
    this.sliderWidth = this.slider.offsetWidth
    this.handleWidth = this.handle.offsetWidth
    this.maxDistance = this.sliderWidth - this.handleWidth - 16
    
    console.log('Slider dimensions:', {
      sliderWidth: this.sliderWidth,
      handleWidth: this.handleWidth,
      maxDistance: this.maxDistance
    })
    
    // Initialize progress bar to 100% before countdown starts
    if (this.progressBar) {
      this.progressBar.style.height = '100%'
    }
    
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
        // Format as :XX (e.g., :07, :06, :05)
        const formatted = this.countdown < 10 ? `:0${this.countdown}` : `:${this.countdown}`
        this.countdownEl.textContent = formatted
      }
      
      // Progress bar goes from 100% to 0% over 6 seconds (one second faster than countdown)
      // This ensures it reaches 0% when countdown shows :00
      const progressPercent = Math.max(0, ((this.countdown - 1) / 6) * 100)
      if (this.progressBar) {
        this.progressBar.style.height = `${progressPercent}%`
      }
      
      if (this.countdown <= 0) {
        clearInterval(this.countdownTimer)
        this.handle.classList.remove('wiggle')
        this.handle.classList.add('disabled')
        this.completed = true // Prevent further dragging
        
        // Wait 1 second before starting fade animations
        setTimeout(() => {
          // Fade out the entire slider section before sending timeout event
          const sliderSection = document.getElementById('video-slider-section')
          if (sliderSection) {
            sliderSection.classList.remove('animate-fade-in')
            sliderSection.classList.add('animate-fade-out')
          }
          
          // Wait for fade-out animation to complete (500ms) before triggering timeout
          setTimeout(() => {
            this.pushEvent('video_collect_timeout', {})
          }, 500)
        }, 1000)
      }
    }, 1000)
  },
  
  setupDrag() {
    const handleMouseDown = (e) => {
      if (this.completed) return // Don't allow dragging if completed/disabled
      
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
      
      // Don't reset position if slide was completed successfully
      if (!this.completed) {
        this.handle.style.transition = 'transform 0.3s ease'
        this.handle.style.transform = 'translateX(0) translateY(-50%)'
        this.handle.classList.add('wiggle')
        this.currentX = 0
      }
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
    
    // Add success styling - keep handle in final position, turn green, pulse
    this.handle.classList.add('success')
    this.slider.classList.add('success')
    if (this.progressBar) {
      this.progressBar.classList.add('success')
    }
    if (this.countdownEl) {
      this.countdownEl.classList.add('success')
    }
    if (this.checkmark) {
      this.checkmark.classList.add('success')
    }
    if (this.handleArrow) {
      this.handleArrow.classList.add('success')
    }
    if (this.handleAmount) {
      this.handleAmount.classList.add('success')
    }
    if (this.destination) {
      this.destination.classList.add('success')
    }
    if (this.message) {
      this.message.textContent = 'Amount collected to wallet.'
      this.message.classList.remove('text-base-content/60')
      this.message.classList.add('text-success')
    }
    
    // Lock the handle in final position (disable dragging)
    this.handle.style.transition = 'none'
    this.handle.style.transform = `translateX(${this.maxDistance}px) translateY(-50%)`
    
    // Send event immediately (no delay)
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

// Extension detection for logging/debugging
const urlParams = new URLSearchParams(window.location.search)
const isExtension = urlParams.get('extension') === 'true'

if (isExtension) {
  console.log('🔌 Extension context')

  window.addEventListener("sponster:close-ext-drawer", () => {
    window.parent.postMessage("close_widget", "*")
  })
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => ({
    _csrf_token: csrfToken,
    current_marketer_id: localStorage.getItem('current_marketer_id'),
    extension: isExtension ? 'true' : null
  }),
  colocatedHooks: colocatedHooks,
  hooks: Hooks
})

// Show progress bar on live navigation and form submits (skip in extension iframe - can cause reload loop)
if (!isExtension) {
  topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, 0.3)"})
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
}

if (isExtension) {
  window.addEventListener("phx:error", (e) => console.warn('[Ext] phx:error', e.detail))
}

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
    
    this.handleEvent("request-push-unsubscribe", async () => {
      console.log("📢 Request push unsubscribe event received")
      await this.unsubscribeFromPush()
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
  },

  async unsubscribeFromPush() {
    try {
      console.log("🔄 Starting push unsubscription...")
      const registration = await navigator.serviceWorker.ready
      console.log("Service worker ready")
      const subscription = await registration.pushManager.getSubscription()
      console.log("Current subscription:", subscription)
      
      if (!subscription) {
        console.log("❌ No subscription found to unsubscribe")
        this.pushEvent("unsubscribe_failed", { error: "No active subscription" })
        return
      }
      
      const endpoint = subscription.endpoint
      console.log("📝 Full endpoint:", endpoint)
      console.log("📝 Unsubscribing from endpoint:", endpoint.substring(0, 50) + "...")
      
      // Unsubscribe from the push service
      const result = await subscription.unsubscribe()
      console.log("Unsubscribe result:", result)
      
      if (result) {
        console.log("✅ Successfully unsubscribed from push service")
        console.log("✅ Sending device_unsubscribed event with endpoint:", endpoint)
        // Notify server to mark subscription as inactive
        this.pushEvent("device_unsubscribed", { endpoint: endpoint })
      } else {
        console.log("❌ Failed to unsubscribe from push service")
        this.pushEvent("unsubscribe_failed", { error: "Unsubscribe returned false" })
      }
    } catch (error) {
      console.error("❌ Failed to unsubscribe from push:", error)
      this.pushEvent("unsubscribe_failed", { error: error.message || error.toString() })
    }
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

Hooks.WalletPulse = {
  mounted() {
    this.lastBalance = this.el.innerText.trim()
    this.lastBalanceNum = this.parseBalance(this.lastBalance)
    
    // Preload the coin sound (shared across all instances)
    if (!window.walletCoinSound) {
      window.walletCoinSound = new Audio('/sounds/coin-clink.wav')
      window.walletCoinSound.volume = 0.5
    }
    this.coinSound = window.walletCoinSound
  },
  
  parseBalance(text) {
    // Strip $ and commas, convert to float
    const cleaned = text.replace(/[$,]/g, '')
    return parseFloat(cleaned) || 0
  },
  
  isSoundEnabled() {
    // Default to true if not set
    const setting = localStorage.getItem('qlarius_wallet_credit_sounds')
    return setting === null ? true : setting === 'true'
  },
  
  updated() {
    const newBalance = this.el.innerText.trim()
    const newBalanceNum = this.parseBalance(newBalance)
    
    if (newBalance !== this.lastBalance) {
      // Balance changed - trigger pulse animation
      this.el.classList.remove('wallet-pulse')
      // Force reflow to restart animation
      void this.el.offsetWidth
      this.el.classList.add('wallet-pulse')
      
      // Play coin sound only when balance increases, sounds enabled, and not recently played
      // Use a global debounce to prevent multiple components from playing simultaneously
      const now = Date.now()
      const lastPlayed = window.walletSoundLastPlayed || 0
      
      if (newBalanceNum > this.lastBalanceNum && this.isSoundEnabled() && (now - lastPlayed > 500)) {
        window.walletSoundLastPlayed = now
        this.coinSound.currentTime = 0
        this.coinSound.play().catch(() => {
          // Ignore errors (sound file missing, autoplay blocked, etc.)
        })
      }
      
      this.lastBalance = newBalance
      this.lastBalanceNum = newBalanceNum
    }
  }
}

// Generic localStorage toggle hook - works with <.local_toggle /> component
Hooks.LocalStorageToggle = {
  mounted() {
    this.storageKey = 'qlarius_' + this.el.dataset.storageKey
    this.defaultValue = this.el.dataset.default !== 'false'
    this.knob = this.el.querySelector('.toggle-knob')
    
    // Load current setting
    const stored = localStorage.getItem(this.storageKey)
    const isEnabled = stored === null ? this.defaultValue : stored === 'true'
    this.setVisualState(isEnabled)
    
    // Handle clicks
    this.el.addEventListener('click', () => {
      const newState = !this.isEnabled
      this.setVisualState(newState)
      localStorage.setItem(this.storageKey, newState)
    })
  },
  
  setVisualState(enabled) {
    this.isEnabled = enabled
    this.el.classList.toggle('bg-success', enabled)
    this.el.classList.toggle('bg-primary', !enabled)
    this.el.setAttribute('aria-checked', enabled)
    if (this.knob) {
      this.knob.classList.toggle('translate-x-6', enabled)
    }
  }
}

// Legacy hook - keep for backwards compatibility, now delegates to LocalStorageToggle pattern
Hooks.AudioAlertSettings = {
  mounted() {
    // The toggle now uses LocalStorageToggle hook directly, this is just a container
    console.log('AudioAlertSettings mounted - toggle uses LocalStorageToggle hook')
  }
}

// Registration Referral Code - reads from localStorage/cookie/CacheStorage and pushes to LiveView
Hooks.RegistrationReferralCode = {
  mounted() {
    console.log('🎯 RegistrationReferralCode hook mounted')
    this.referralPushed = false
    
    const storedCode = this.getStoredReferralCode()
    console.log('🎯 Checking storage for referral code:', storedCode || '(none found)')
    
    if (storedCode) {
      this.pushReferralToLiveView(storedCode)
    } else {
      // Try Cache Storage (shared on iOS between Safari and PWA)
      this.tryLoadFromCacheStorage()
    }
    
    // Also listen for the event from root script's Cache Storage load
    window.addEventListener('referral-code-loaded', (e) => {
      if (e.detail && !this.referralPushed) {
        console.log('🎯 Got referral from Cache Storage event:', e.detail)
        this.pushReferralToLiveView(e.detail)
      }
    }, { once: true })
  },
  
  pushReferralToLiveView(code) {
    if (this.referralPushed) return
    this.referralPushed = true
    setTimeout(() => {
      console.log('🎯 Pushing referral code to LiveView:', code)
      this.pushEvent("referral_code_from_storage", { code: code })
    }, 100)
  },
  
  tryLoadFromCacheStorage() {
    const REFERRAL_ENDPOINT = '/_shared/referral-code'
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then(() => {
        fetch(REFERRAL_ENDPOINT).then(r => r.json()).then(data => {
          if (data.referral_code && !this.referralPushed) {
            console.log('🎯 Loaded referral from Cache Storage:', data.referral_code)
            try { localStorage.setItem('qadabra_referral_code', data.referral_code) } catch (e) {}
            this.pushReferralToLiveView(data.referral_code)
          }
        }).catch(() => {})
      })
    }
  },
  
  getStoredReferralCode() {
    try {
      const lsCode = localStorage.getItem('qadabra_referral_code')
      if (lsCode) return lsCode
    } catch (e) {}
    
    const cookies = document.cookie.split(';').reduce((acc, cookie) => {
      const [key, value] = cookie.trim().split('=')
      if (key && value) acc[key] = decodeURIComponent(value)
      return acc
    }, {})
    return cookies['qadabra_referral_code'] || null
  }
}

// Date Input - 3-field MM/DD/YYYY with auto-advance and validation
Hooks.DateInput = {
  mounted() {
    this.fields = this.el.querySelectorAll('.date-field')
    this.monthField = this.el.querySelector('[data-field="month"]')
    this.dayField = this.el.querySelector('[data-field="day"]')
    this.yearField = this.el.querySelector('[data-field="year"]')
    this.updateEvent = this.el.dataset.updateEvent || 'update_birthdate'
    this.minAge = parseInt(this.el.dataset.minAge) || 16
    
    // Field order for navigation
    this.fieldOrder = [this.monthField, this.dayField, this.yearField]
    this.fieldLengths = { month: 2, day: 2, year: 4 }
    
    this.fields.forEach((field, index) => {
      const fieldName = field.dataset.field
      const maxLen = this.fieldLengths[fieldName]
      
      // Handle input
      field.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '')
        
        // Validate first digit based on field
        if (value.length >= 1) {
          const firstDigit = parseInt(value[0])
          if (fieldName === 'month' && firstDigit > 1) {
            value = ''
          } else if (fieldName === 'day' && firstDigit > 3) {
            value = ''
          } else if (fieldName === 'year' && firstDigit !== 1 && firstDigit !== 2) {
            value = ''
          }
        }
        
        // Validate second digit for month (01-12)
        if (fieldName === 'month' && value.length >= 2) {
          const monthNum = parseInt(value.slice(0, 2))
          if (monthNum < 1 || monthNum > 12) {
            value = value[0] // Keep first digit, remove invalid second
          }
        }
        
        // Validate second digit for day (01-31)
        if (fieldName === 'day' && value.length >= 2) {
          const dayNum = parseInt(value.slice(0, 2))
          if (dayNum < 1 || dayNum > 31) {
            value = value[0]
          }
        }
        
        // Truncate to max length
        value = value.slice(0, maxLen)
        e.target.value = value
        
        // Auto-advance when field is complete
        if (value.length === maxLen && index < this.fieldOrder.length - 1) {
          this.fieldOrder[index + 1].focus()
        }
        
        this.pushUpdate()
      })
      
      // Handle backspace navigation
      field.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && e.target.value === '' && index > 0) {
          e.preventDefault()
          const prevField = this.fieldOrder[index - 1]
          prevField.focus()
          // Select the content so next backspace clears it
          prevField.select()
        }
      })
      
      // Select all on focus
      field.addEventListener('focus', (e) => {
        if (e.target.value) {
          e.target.select()
        }
      })
    })
    
    // Focus month field on mount
    this.monthField.focus()
  },
  
  pushUpdate() {
    const month = this.monthField.value
    const day = this.dayField.value
    const year = this.yearField.value
    
    this.pushEvent(this.updateEvent, {
      month: month,
      day: day,
      year: year
    })
  },
  
  // Sync with server state
  updated() {
    // Fields are already bound to server values via value attribute
  }
}

// OTP Input - Single input with visual slots (inspired by input-otp library)
// Uses one real input for reliability - handles paste, autofill, keyboard naturally
Hooks.OTPInput = {
  mounted() {
    this.input = this.el.querySelector('.otp-input')
    this.slots = this.el.querySelectorAll('.otp-slot')
    this.length = 6
    
    // Get configurable event names from data attributes
    this.verifyEvent = this.el.dataset.verifyEvent || 'verify_code'
    this.updateEvent = this.el.dataset.updateEvent || 'update_verification_code'
    
    // Handle input changes
    this.input.addEventListener('input', (e) => {
      // Strip non-digits and limit to 6
      let value = e.target.value.replace(/\D/g, '').slice(0, this.length)
      e.target.value = value
      
      // Update visual slots
      this.updateSlots(value)
      
      // Push to LiveView
      this.pushEvent(this.updateEvent, { verification_code: value })
      
      // Auto-submit when complete
      if (value.length === this.length) {
        this.pushEvent(this.verifyEvent, { code: value })
      }
    })
    
    // Handle focus - highlight active slot
    this.input.addEventListener('focus', () => {
      this.updateActiveSlot()
    })
    
    this.input.addEventListener('blur', () => {
      this.slots.forEach(slot => slot.classList.remove('ring-2', 'ring-primary'))
    })
    
    // Update active slot on selection change
    this.input.addEventListener('keyup', () => this.updateActiveSlot())
    this.input.addEventListener('click', () => this.updateActiveSlot())
    
    // No auto-focus - user tap triggers autofill reliably
    // The pulsing first slot draws attention to tap
  },
  
  updateSlots(value) {
    const chars = value.split('')
    this.slots.forEach((slot, i) => {
      slot.textContent = chars[i] || ''
    })
    this.updateActiveSlot()
  },
  
  updateActiveSlot() {
    const pos = Math.min(this.input.value.length, this.length - 1)
    this.slots.forEach((slot, i) => {
      if (i === pos && document.activeElement === this.input) {
        slot.classList.add('ring-2', 'ring-primary')
      } else {
        slot.classList.remove('ring-2', 'ring-primary')
      }
    })
  },
  
  // Handle server-side updates (e.g., clear on error)
  updated() {
    const serverValue = this.el.dataset.value || ''
    if (this.input.value !== serverValue) {
      this.input.value = serverValue
      this.updateSlots(serverValue)
      if (serverValue === '') {
        this.input.focus()
      }
    }
  }
}

// Register service worker for PWA (but NOT in extension context to avoid caching issues)
if ("serviceWorker" in navigator && !isExtension) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js")
      .then(registration => {
        console.log("✅ Service Worker registered:", registration.scope)
      })
      .catch(error => {
        console.error("❌ Service Worker registration failed:", error)
      })
  })
} else if (isExtension) {
  console.log("🚫 Service Worker disabled in extension context (skip register; do NOT unregister - unregister can trigger reload loop)")
} else {
  console.warn("❌ Service Worker not supported in this browser")
}

