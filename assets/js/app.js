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
import {computePosition, flip, shift, offset, arrow, size, autoUpdate} from "@floating-ui/dom"

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

// Ref-counted `overflow-hidden` on `document.body` so overlapping overlays
// (e.g. AuthSheet + nested widget modal) don't unlock early. Matches
// `JS.add_class("overflow-hidden", to: "body")` used by `<.modal>`.
Hooks.BodyScrollLock = {
  mounted() {
    this._applied = false
    this._sync()
  },
  updated() {
    this._sync()
  },
  destroyed() {
    this._set(false)
  },
  _wantLock() {
    return this.el.dataset.bodyScrollLock === "true"
  },
  _sync() {
    this._set(this._wantLock())
  },
  _set(want) {
    if (want === this._applied) return
    if (want) {
      window.__qlariusBodyScrollLock =
        (typeof window.__qlariusBodyScrollLock === "number" ? window.__qlariusBodyScrollLock : 0) + 1
      this._applied = true
      if (window.__qlariusBodyScrollLock === 1) {
        document.body.classList.add("overflow-hidden")
      }
    } else if (this._applied) {
      window.__qlariusBodyScrollLock = Math.max(
        0,
        (typeof window.__qlariusBodyScrollLock === "number" ? window.__qlariusBodyScrollLock : 1) - 1
      )
      this._applied = false
      if (window.__qlariusBodyScrollLock === 0) {
        document.body.classList.remove("overflow-hidden")
      }
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

function detectIosPwa() {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
  const isPWA = window.matchMedia('(display-mode: standalone)').matches ||
                window.navigator.standalone === true
  return isIOS && isPWA
}

function applyIosPwaLayoutFix() {
  if (!detectIosPwa()) return
  document.documentElement.classList.add('ios-pwa')
}

Hooks.PWADetect = {
  mounted() {
    applyIosPwaLayoutFix()

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

      this.pushEvent("pwa_detected", {
        is_pwa: isPWA,
        in_iframe: inIframe,
        is_mobile: isMobile,
        device_type: deviceType
      })
    }, 100)
  },

  applySafeAreaFix() {
    document.documentElement.style.setProperty('--safe-area-inset-bottom-js', '0px')
  },

  applyViewportFix() {
    const setViewportHeight = () => {
      const vh = window.innerHeight
      document.documentElement.style.setProperty('--app-height', `${vh}px`)
      console.log('[Viewport Fix] Set --app-height to', vh)
    }

    setViewportHeight()
    window.addEventListener('resize', setViewportHeight)
    setTimeout(setViewportHeight, 100)
    setTimeout(setViewportHeight, 500)
  }
}

// Persist "continue in browser" so protected routes skip /hi PWA redirect.
const MOBILE_BROWSER_OK_COOKIE = 'mobile_browser_ok=true; path=/; max-age=31536000; SameSite=Lax'

if (!window.__qlariusMobileBrowserOkListener) {
  window.__qlariusMobileBrowserOkListener = true
  window.addEventListener('qlarius:store-mobile-browser-ok', () => {
    document.cookie = MOBILE_BROWSER_OK_COOKIE
  })
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
    this.bindCarouselIndicators()
  },

  updated() {
    // LiveView re-renders (e.g. manifesto dismiss) reset indicator classes from the template
    this.bindCarouselIndicators()
  },

  destroyed() {
    this.teardownCarouselIndicators?.()
  },

  bindCarouselIndicators() {
    this.teardownCarouselIndicators?.()

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
      const { pages } = calculatePagination()
      const scrollLeft = carousel.scrollLeft
      const maxScroll = carousel.scrollWidth - carousel.offsetWidth

      let currentPage = 0
      if (maxScroll > 0) {
        const scrollProgress = scrollLeft / maxScroll
        currentPage = Math.min(pages - 1, Math.floor(scrollProgress * pages))
      }

      const indicatorContainer = indicators[0]?.parentElement
      if (indicatorContainer) {
        if (pages <= 1) {
          indicatorContainer.style.display = 'none'
        } else {
          indicatorContainer.style.display = 'flex'
        }
      }

      indicators.forEach((indicator, index) => {
        if (index < pages) {
          indicator.style.display = 'block'

          if (index === currentPage) {
            indicator.classList.remove('bg-base-content/30', 'w-3')
            indicator.classList.add('bg-primary', 'w-6')
          } else {
            indicator.classList.remove('bg-primary', 'w-6')
            indicator.classList.add('bg-base-content/30', 'w-3')
          }
        } else {
          indicator.style.display = 'none'
        }
      })
    }

    const scheduleUpdate = () => {
      requestAnimationFrame(() => {
        updateIndicators()
        requestAnimationFrame(updateIndicators)
      })
    }

    carousel.addEventListener('scroll', updateIndicators)

    let resizeTimeout
    const onResize = () => {
      clearTimeout(resizeTimeout)
      resizeTimeout = setTimeout(scheduleUpdate, 100)
    }
    window.addEventListener('resize', onResize)

    const resizeObserver = new ResizeObserver(() => scheduleUpdate())
    resizeObserver.observe(carousel)

    scheduleUpdate()
    setTimeout(scheduleUpdate, 100)

    this.teardownCarouselIndicators = () => {
      carousel.removeEventListener('scroll', updateIndicators)
      window.removeEventListener('resize', onResize)
      resizeObserver.disconnect()
      clearTimeout(resizeTimeout)
    }

    this.updateIndicators = updateIndicators
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
    this.pendingTimers = []

    this.handleEvent("animate_trait", ({trait_id, delay_ms, value}) => {
      const delay = typeof delay_ms === "number" ? delay_ms : 250
      const timer = setTimeout(() => this.playTraitAnimation(trait_id, value), delay)
      this.pendingTimers.push(timer)
    })
  },

  destroyed() {
    if (this.pendingTimers) {
      this.pendingTimers.forEach((timer) => clearTimeout(timer))
      this.pendingTimers = []
    }
  },

  playTraitAnimation(traitId, value) {
    const durationMs = 950
    const animationClass =
      value === "delete_fade" ? "trait-animate-delete" : "trait-animate-update"

    const findAndAnimate = (attempt = 0) => {
      const el = document.getElementById(`trait-card-${traitId}`)
      if (!el) {
        if (attempt < 16) requestAnimationFrame(() => findAndAnimate(attempt + 1))
        return
      }

      if (el.dataset.traitAnimating === "true") return

      document.documentElement.style.pointerEvents = ""
      document.body.style.pointerEvents = ""

      el.classList.remove("trait-animate-update", "trait-animate-delete")
      void el.offsetWidth

      const cleanup = () => {
        delete el.dataset.traitAnimating
        el.classList.remove("trait-animate-update", "trait-animate-delete")
      }

      el.dataset.traitAnimating = "true"
      el.classList.add(animationClass)

      const doneTimer = setTimeout(cleanup, durationMs + 100)
      this.pendingTimers.push(doneTimer)
    }

    findAndAnimate()
  },
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
    const format = el.dataset.countdownFormat || 'friendly'
    if (format === 'hms') {
      const totalH = Math.floor(distance / (1000 * 60 * 60))
      const m = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60))
      const s = Math.floor((distance % (1000 * 60)) / 1000)
      display.textContent = [
        String(totalH).padStart(2, '0'),
        String(m).padStart(2, '0'),
        String(s).padStart(2, '0')
      ].join(':')
    } else {
      const d = Math.floor(distance / (1000*60*60*24))
      const h = Math.floor((distance % (1000*60*60*24)) / (1000*60*60))
      const m = Math.floor((distance % (1000*60*60)) / (1000*60))
      const s = Math.floor((distance % (1000*60)) / 1000)
      const parts = []
      if (d > 0) parts.push(`${d} ${d===1?'day':'days'}`)
      if (h > 0 || d > 0) parts.push(`${h} ${h===1?'hr':'hrs'}`)
      if (d < 1) parts.push(`${m} ${m===1?'min':'mins'}`)
      if (d < 1 && h < 1 && m < 10) parts.push(`${s} ${s===1?'sec':'secs'}`)
      display.textContent = parts.join(', ')
    }
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

// Smooth close for tiqit ticket `<details>` tail — keep [open] until animation completes.
Hooks.TiqitTailDetails = {
  mounted() {
    this.summary = this.el.querySelector("summary")
    if (!this.summary) return

    this.onSummaryClick = (event) => {
      if (!this.el.open || this.closing) return
      event.preventDefault()
      event.stopPropagation()
      this.beginClose()
    }

    this.onToggle = () => {
      if (this.closing) {
        if (!this.el.open) this.el.open = true
        return
      }

      if (this.el.open) {
        this.clearCloseState()
        this.maybeAnimateOpen()
      }
    }

    this.onOpenTransitionEnd = (event) => {
      if (event.target !== this.el) return
      if (event.propertyName !== "height") return
      if (!this.el.classList.contains("tiqit-tail-animate-open")) return
      this.el.classList.remove("tiqit-tail-animate-open")
    }

    this.summary.addEventListener("click", this.onSummaryClick, true)
    this.el.addEventListener("toggle", this.onToggle)
    this.el.addEventListener("transitionend", this.onOpenTransitionEnd)
  },

  updated() {
    this.summary = this.el.querySelector("summary")

    if (this.closing && this.el.open) {
      this.el.classList.add("tiqit-tail-is-closing")
      const h = this.el.style.getPropertyValue("--tiqit-tail-content-h")
      if (!h || h.trim() === "") {
        this.el.style.setProperty("--tiqit-tail-content-h", "0px")
      }
    }
  },

  destroyed() {
    this.summary?.removeEventListener("click", this.onSummaryClick, true)
    this.el.removeEventListener("toggle", this.onToggle)
    this.el.removeEventListener("transitionend", this.onOpenTransitionEnd)
    this.cancelCloseRaf()
    this.clearCloseTimer()
    this.closing = false
  },

  beginClose() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.clearCloseState()
      this.el.open = false
      return
    }

    if (!this.supportsAnimatedDetailsContent()) {
      this.clearCloseState()
      this.el.open = false
      return
    }

    this.closing = true
    const duration = this.tailDurationMs()
    const height = this.el.scrollHeight

    this.el.classList.remove("tiqit-tail-animate-open")
    this.el.classList.add("tiqit-tail-is-closing")
    this.el.style.setProperty("--tiqit-tail-content-h", `${height}px`)
    this.el.getBoundingClientRect()

    this.cancelCloseRaf()
    this.closeRaf = requestAnimationFrame(() => {
      this.closeRaf = null
      this.el.style.setProperty("--tiqit-tail-content-h", "0px")
    })

    this.clearCloseTimer()
    this.closeTimer = window.setTimeout(() => this.finishClose(), duration + 80)
  },

  finishClose() {
    if (!this.closing) return

    this.cancelCloseRaf()
    this.clearCloseTimer()

    // Kill ::details-content height transition before removing [open] (avoids second collapse).
    this.el.classList.add("tiqit-tail-instant-shut")
    this.el.removeAttribute("open")
    this.el.style.removeProperty("--tiqit-tail-content-h")
    this.closing = false

    requestAnimationFrame(() => {
      this.el.classList.remove("tiqit-tail-is-closing", "tiqit-tail-instant-shut")
    })
  },

  clearCloseState() {
    this.el.classList.remove("tiqit-tail-is-closing", "tiqit-tail-instant-shut")
    this.el.style.removeProperty("--tiqit-tail-content-h")
  },

  maybeAnimateOpen() {
    if (!this.supportsAnimatedDetailsContent()) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.el.classList.add("tiqit-tail-animate-open")
  },

  supportsAnimatedDetailsContent() {
    return (
      CSS.supports("interpolate-size", "allow-keywords") &&
      CSS.supports("selector(details::details-content)")
    )
  },

  cancelCloseRaf() {
    if (this.closeRaf) {
      cancelAnimationFrame(this.closeRaf)
      this.closeRaf = null
    }
  },

  tailDurationMs() {
    const grid = this.el.closest(".tiqit-grid")
    const source = grid || this.el
    const raw = getComputedStyle(source).getPropertyValue("--tiqit-tail-t").trim()
    if (!raw) return 520
    if (raw.endsWith("ms")) return parseFloat(raw)
    return parseFloat(raw) * 1000
  },

  clearCloseTimer() {
    if (this.closeTimer) {
      window.clearTimeout(this.closeTimer)
      this.closeTimer = null
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

/** Qlink Sponster: split settings panel disclaimer peek uses measured bar height (see app.css). */
Hooks.QlinkSplitDisclaimerPeek = {
  mounted() {
    this._resizeObserver = null
    this.syncDisclaimerPeekHeight()
  },

  updated() {
    this.syncDisclaimerPeekHeight()
  },

  destroyed() {
    this.disconnectDisclaimerResizeObserver()
  },

  disconnectDisclaimerResizeObserver() {
    if (this._resizeObserver) {
      this._resizeObserver.disconnect()
      this._resizeObserver = null
    }
  },

  syncDisclaimerPeekHeight() {
    const state = this.el.dataset.splitPanelState
    this.disconnectDisclaimerResizeObserver()

    if (state !== 'peek') {
      this.el.style.removeProperty('--qlink-peek-disclaimer-px')
      return
    }

    const apply = () => {
      const slot = document.getElementById('qlink-split-disclaimer-slot')
      if (!slot) return
      const h = Math.ceil(slot.getBoundingClientRect().height)
      if (h > 0) {
        this.el.style.setProperty('--qlink-peek-disclaimer-px', `${h}px`)
      }
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        apply()
        const slot = document.getElementById('qlink-split-disclaimer-slot')
        if (!slot || typeof ResizeObserver === 'undefined') return
        this._resizeObserver = new ResizeObserver(() => {
          if (this.el.dataset.splitPanelState !== 'peek') return
          apply()
        })
        this._resizeObserver.observe(slot)
      })
    })
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

Hooks.HideOpenInTabWhenFullscreen = {
  mounted() {
    // "Open in new tab" is for breaking out of embeds. Show whenever we're
    // not already on a dedicated full-tab Arqade group URL in the top window.
    // - Iframe (any URL): always show.
    // - Top-level /widgets/arqade/group/:id or /arqade/group/:id: hide (already full-screen).
    // - Top-level Qlink, etc.: show.
    if (window.self !== window.top) return

    const p = window.location.pathname
    const widgetGroup = /^\/widgets\/arqade\/group\/[^/]+/.test(p)
    const appGroup = /^\/arqade\/group\/[^/]+/.test(p)

    if (widgetGroup || appGroup) this.el.classList.add('hidden')
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

Hooks.EpisodeSearchField = {
  mounted() {
    this._onInput = () => this.syncClear()
    this.input()?.addEventListener('input', this._onInput)
    this.syncClear()
  },
  updated() {
    this.syncClear()
  },
  destroyed() {
    this.input()?.removeEventListener('input', this._onInput)
  },
  input() {
    return this.el.querySelector('[data-episode-search-input]')
  },
  clearBtn() {
    return this.el.querySelector('[data-episode-search-clear]')
  },
  syncClear() {
    const input = this.input()
    const btn = this.clearBtn()
    if (!input || !btn) return
    const show = input.value.length > 0
    btn.classList.toggle('hidden', !show)
    btn.classList.toggle('inline-flex', show)
  }
}

Hooks.YouTubePoster = {
  mounted() {
    const youtubeId = this.el.dataset.youtubeId
    const iframe =
      this.el.parentElement.querySelector('iframe.tiqit-yt-embed') ||
      this.el.parentElement.querySelector('iframe')
    if (!iframe || !youtubeId) return

    this.el.addEventListener('click', () => {
      this.el.classList.add('hidden')
      iframe.classList.remove('hidden')
      iframe.src = `https://www.youtube.com/embed/${youtubeId}?autoplay=1`
    })
  }
}

Hooks.Popover = {
  mounted() {
    this.triggerEl = this.el.querySelector("[data-popover-trigger]")
    this.contentEl = this.el.querySelector("[data-popover-content]")
    this.arrowEl = this.el.querySelector("[data-popover-arrow]")
    if (!this.triggerEl || !this.contentEl) return

    this.placement = this.el.dataset.placement || "bottom"
    this.triggerType = this.el.dataset.trigger || "click"
    this.offsetPx = parseInt(this.el.dataset.offset || "8", 10)
    this.shiftPadding = parseInt(this.el.getAttribute("data-shift-padding") || "8", 10) || 8
    this.positionStrategy = this.el.dataset.positionStrategy || "absolute"
    this.arrowAlign = (this.el.dataset.popoverArrowAlign || "reference").toLowerCase()
    this.flipEnabled = this.el.getAttribute("data-flip") !== "false"
    this.useFloatingSize = this.el.getAttribute("data-popover-use-floating-size") !== "false"
    this.isOpen = false
    this.cleanupAutoUpdate = null
    this._portaled = false

    this._runPosition = () => {
      return computePosition(this.triggerEl, this.contentEl, {
        strategy: this.positionStrategy,
        placement: this.placement,
        middleware: this._buildMiddleware()
      }).then(({ x, y, placement, middlewareData }) => {
        Object.assign(this.contentEl.style, { left: `${x}px`, top: `${y}px` })
        this._positionArrow(placement, middlewareData)
      })
    }

    this.show = this.show.bind(this)
    this.hide = this.hide.bind(this)
    this.toggle = this.toggle.bind(this)
    this.onClickOutside = this.onClickOutside.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
    this._portalMarker = null

    this._onExternalCloseRequest = (ev) => {
      if (!ev.detail || ev.detail.id !== this.el.id) return
      this.hide()
    }
    window.addEventListener("qlarius:close-popover", this._onExternalCloseRequest)

    if (this.triggerType === "click") {
      this.triggerEl.addEventListener("click", this.toggle)
    } else if (this.triggerType === "hover") {
      this.triggerEl.addEventListener("mouseenter", this.show)
      this.triggerEl.addEventListener("mouseleave", this.hide)
      this.contentEl.addEventListener("mouseenter", this.show)
      this.contentEl.addEventListener("mouseleave", this.hide)
      this.triggerEl.addEventListener("focus", this.show)
      this.triggerEl.addEventListener("blur", this.hide)
    } else if (this.triggerType === "focus") {
      this.triggerEl.addEventListener("focus", this.show)
      this.triggerEl.addEventListener("blur", this.hide)
    }
  },

  /**
   * Portal fixed panels only while open. Porting on `mounted` duplicates IDs when
   * LiveView patches the hook (new DOM + old node still in `document.body`).
   */
  _portalFixedToBody() {
    if (this.positionStrategy !== "fixed" || this._portaled || !this.contentEl?.parentNode) return
    this._portalMarker = document.createComment("popover-fixed-anchor")
    this.contentEl.parentNode.insertBefore(this._portalMarker, this.contentEl)
    document.body.appendChild(this.contentEl)
    this._portaled = true
    this._syncPortaledTheme()
  },

  _resolveDataTheme(el) {
    if (!el?.closest) {
      return document.documentElement.getAttribute("data-theme") || "light"
    }
    const themed = el.closest("[data-theme]")
    return (
      themed?.getAttribute("data-theme") ||
      document.documentElement.getAttribute("data-theme") ||
      "light"
    )
  },

  _syncPortaledTheme() {
    if (!this.contentEl || !this._portaled) return
    const theme = this._resolveDataTheme(this.triggerEl)
    this.contentEl.setAttribute("data-theme", theme)
    if (this.arrowEl) this.arrowEl.setAttribute("data-theme", theme)
  },

  _restoreFixedPortal() {
    if (!this._portaled || !this.contentEl) return
    if (this._portalMarker?.parentNode) {
      this._portalMarker.parentNode.insertBefore(this.contentEl, this._portalMarker)
    }
    this._portalMarker?.remove()
    this._portalMarker = null
    this._portaled = false
  },

  _syncToggleLabels() {
    if (!this.triggerEl) return
    const a = this.triggerEl.querySelector('[data-popover-toggle-label="show"]')
    const b = this.triggerEl.querySelector('[data-popover-toggle-label="hide"]')
    if (!a || !b) return
    a.classList.toggle("hidden", this.isOpen)
    b.classList.toggle("hidden", !this.isOpen)
  },

  _buildMiddleware() {
    const p = this.shiftPadding
    // shift+size share this padding; extra top for top*+fixed. size: always maxHeight; h=0 uses small fallback
    const padding = { top: p + 32, right: p, bottom: p, left: p }
    const mw = [offset(this.offsetPx)]
    if (this.flipEnabled) mw.push(flip())
    mw.push(shift({ padding, rootBoundary: "viewport" }))
    if (this.useFloatingSize) {
      mw.push(
        size({
          apply: ({ availableWidth, availableHeight, elements }) => {
            let w = Math.max(0, availableWidth)
            const fr = this.el.getAttribute("data-floating-width-cap-frac-md")
            if (
              fr != null &&
              fr !== "" &&
              typeof window !== "undefined" &&
              window.matchMedia("(min-width: 768px)").matches
            ) {
              const frac = parseFloat(fr, 10)
              if (Number.isFinite(frac) && frac > 0) {
                // half-column cap: 80px inset from column split (tune in one place)
                const cap = Math.max(0, window.innerWidth * frac - 80)
                w = Math.min(w, cap)
              }
            }
            let h = Math.max(0, availableHeight)
            if (h === 0 && typeof window !== "undefined") {
              h = Math.max(0, Math.min(240, window.innerHeight * 0.35 - 8))
            }
            if (w > 0) elements.floating.style.maxWidth = `${w}px`
            else elements.floating.style.removeProperty("max-width")
            elements.floating.style.maxHeight = `${h}px`
          },
          padding
        })
      )
    }
    if (this.arrowEl) {
      const pl = this.placement || ""
      const isTopOrBottom = /^(top|bottom)(-|$)/.test(pl)
      if (this.arrowAlign !== "end" || !isTopOrBottom) {
        mw.push(arrow({ element: this.arrowEl, padding: 4 }))
      }
    }
    return mw
  },

  _positionArrow(placement, middlewareData) {
    if (!this.arrowEl) return
    const mainSide = placement.split("-")[0]
    if (this.arrowAlign === "end" && (mainSide === "top" || mainSide === "bottom")) {
      this.arrowEl.style.top = "auto"
      this.arrowEl.style.left = "auto"
      this.arrowEl.style.right = "0.75rem"
      if (mainSide === "top") {
        this.arrowEl.style.bottom = "-4px"
        this.arrowEl.dataset.side = "bottom"
      } else {
        this.arrowEl.style.bottom = "auto"
        this.arrowEl.style.top = "-4px"
        this.arrowEl.dataset.side = "top"
      }
      return
    }
    const { x: ax, y: ay } = middlewareData.arrow || {}
    const staticSide = { top: "bottom", right: "left", bottom: "top", left: "right" }[mainSide]
    if (!staticSide) return
    Object.assign(this.arrowEl.style, {
      left: ax != null ? `${ax}px` : "",
      top: ay != null ? `${ay}px` : "",
      right: "",
      bottom: "",
      [staticSide]: "-4px"
    })
    this.arrowEl.dataset.side = staticSide
  },

  show() {
    if (this.isOpen) return
    this._portalFixedToBody()
    this.isOpen = true

    this.contentEl.classList.remove("hidden")
    requestAnimationFrame(() => {
      if (!this.isOpen) return
      this.contentEl.classList.remove("opacity-0")
      this.cleanupAutoUpdate = autoUpdate(this.triggerEl, this.contentEl, this._runPosition) // first measure after unhide
    })
    this.triggerEl.setAttribute("aria-expanded", "true")
    this._syncToggleLabels()

    if (this.triggerType === "click") {
      document.addEventListener("click", this.onClickOutside, true)
    }
    document.addEventListener("keydown", this.onKeyDown)
  },

  hide() {
    if (!this.isOpen) return
    this.isOpen = false

    this.contentEl.classList.add("opacity-0")
    this.triggerEl.setAttribute("aria-expanded", "false")
    this._syncToggleLabels()

    const duration = 150
    setTimeout(() => {
      if (!this.isOpen) {
        this.contentEl.classList.add("hidden")
        // clear only after display:none; during fade, dropped max-* reflows full height and flashes
        this.contentEl.style.removeProperty("max-width")
        this.contentEl.style.removeProperty("max-height")
        this._restoreFixedPortal()
      }
    }, duration)

    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
      this.cleanupAutoUpdate = null
    }

    document.removeEventListener("click", this.onClickOutside, true)
    document.removeEventListener("keydown", this.onKeyDown)
  },

  toggle() {
    this.isOpen ? this.hide() : this.show()
  },

  onClickOutside(e) {
    const inTriggerTree = this.el.contains(e.target)
    const inPanel = this.contentEl && this.contentEl.contains(e.target)
    if (!inTriggerTree && !inPanel) {
      this.hide()
    }
  },

  onKeyDown(e) {
    if (e.key === "Escape") {
      this.hide()
      this.triggerEl.focus()
    }
  },

  updated() {
    const nextContent = this.el.querySelector("[data-popover-content]")
    const nextArrow = this.el.querySelector("[data-popover-arrow]")
    if (nextContent && nextContent !== this.contentEl) {
      if (this.cleanupAutoUpdate) {
        this.cleanupAutoUpdate()
        this.cleanupAutoUpdate = null
      }
      if (this.contentEl?.parentNode === document.body) {
        this.contentEl.remove()
      }
      this.contentEl = nextContent
      this.arrowEl = nextArrow || null
      this._portaled = false
      this._portalMarker = null
      if (this.isOpen) {
        this._portalFixedToBody()
        this.contentEl.classList.remove("hidden", "opacity-0")
        requestAnimationFrame(() => {
          if (this.isOpen) {
            this.cleanupAutoUpdate = autoUpdate(this.triggerEl, this.contentEl, this._runPosition)
          }
        })
        return
      }
    }
    if (!this.isOpen || !this.cleanupAutoUpdate) return
    this.cleanupAutoUpdate()
    requestAnimationFrame(() => {
      if (this.isOpen) {
        this.cleanupAutoUpdate = autoUpdate(this.triggerEl, this.contentEl, this._runPosition)
      }
    })
  },

  destroyed() {
    if (this._onExternalCloseRequest) {
      window.removeEventListener("qlarius:close-popover", this._onExternalCloseRequest)
      this._onExternalCloseRequest = null
    }
    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
      this.cleanupAutoUpdate = null
    }
    document.removeEventListener("click", this.onClickOutside, true)
    document.removeEventListener("keydown", this.onKeyDown)
    this._restoreFixedPortal()
    if (this.triggerType === "click") {
      this.triggerEl.removeEventListener("click", this.toggle)
    } else if (this.triggerType === "hover") {
      this.triggerEl.removeEventListener("mouseenter", this.show)
      this.triggerEl.removeEventListener("mouseleave", this.hide)
      this.contentEl.removeEventListener("mouseenter", this.show)
      this.contentEl.removeEventListener("mouseleave", this.hide)
      this.triggerEl.removeEventListener("focus", this.show)
      this.triggerEl.removeEventListener("blur", this.hide)
    } else if (this.triggerType === "focus") {
      this.triggerEl.removeEventListener("focus", this.show)
      this.triggerEl.removeEventListener("blur", this.hide)
    }
  }
}

/**
 * Wallet top-up → Sponster: fade the popover out first (Popover hook listens for
 * qlarius:close-popover), then push open-sponster-drawer so the drawer animates after.
 */
Hooks.WalletTopupOpenSponster = {
  mounted() {
    this._onClick = (e) => {
      e.stopPropagation()
      const popoverId = this.el.dataset.popoverId
      if (popoverId) {
        window.dispatchEvent(new CustomEvent("qlarius:close-popover", { detail: { id: popoverId } }))
      }
      const ms = parseInt(this.el.dataset.drawerDelayMs || "280", 10)
      this._timer = window.setTimeout(() => {
        this._timer = null
        this.pushEvent("open-sponster-drawer", {})
      }, ms)
    }
    this.el.addEventListener("click", this._onClick)
  },
  destroyed() {
    this.el.removeEventListener("click", this._onClick)
    if (this._timer) {
      window.clearTimeout(this._timer)
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

Hooks.MeFilePanelScroll = {
  mounted() {
    this.handleEvent("scroll-mefile-tags-to-top", () => {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => this._scrollPanelToTop())
      })
    })
  },

  _scrollPanelToTop() {
    const tagsDisplay = document.getElementById("mefile-tags-display")
    const scrollContainer = tagsDisplay?.closest(".panel-scroll")
    if (scrollContainer) {
      scrollContainer.scrollTop = 0
    }
  },
}

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

// AuthSheet: detects whether the sheet is running inside an iframe and
// reports it to the LiveComponent so it can swap to the link-out
// interstitial instead of attempting in-place auth (which can't set
// top-frame cookies reliably). See docs/qlink_auth_refactor_plan.md §5.2.
Hooks.IframeDetect = {
  mounted() {
    // `self !== top` is true in some in-app shells (e.g. Reddit) even when
    // this document is the user's navigated page, not our embed — which
    // incorrectly forced the "open in new tab" auth interstitial.
    // `frameElement` is non-null only when this document is actually
    // loaded inside an HTML iframe.
    const inIframe = window.frameElement != null
    // Round-trip through the component so server-side rendering stays
    // authoritative — client is a hint, not a source of truth.
    this.pushEventTo(this.el, "iframe-status", { in_iframe: inIframe })
  }
}

const IAB_ESCAPE_SHOW_DELAY_MS = 1000
const IAB_ESCAPE_CLOSE_MS = 300

Hooks.InAppEscapePopover = {
  mounted() {
    try {
      if (localStorage.getItem("qlarius_iab_escape_dismissed") === "1") {
        this.pushEvent("iab_escape_client_dismissed", {})
        return
      }
    } catch (_e) {}

    this.handleEvent("iab_escape_store_dismiss", () => {
      try {
        localStorage.setItem("qlarius_iab_escape_dismissed", "1")
      } catch (_e) {}
    })

    this.backdrop = this.el.querySelector("[data-iab-escape-backdrop]")
    this.onBackdropClick = () => this.dismiss()

    if (this.backdrop) {
      this.backdrop.addEventListener("click", this.onBackdropClick)
    }

    this.dismissButtons = this.el.querySelectorAll("[data-iab-escape-dismiss]")
    this.onDismissClick = (e) => {
      e.preventDefault()
      this.dismiss()
    }
    this.dismissButtons.forEach((btn) =>
      btn.addEventListener("click", this.onDismissClick)
    )

    this.showTimer = setTimeout(() => {
      this.el.classList.add("iab-escape-popover-active")
      this.el.setAttribute("aria-hidden", "false")
      const panel = this.el.querySelector("[data-iab-escape-panel]")
      panel?.setAttribute("aria-hidden", "false")
    }, IAB_ESCAPE_SHOW_DELAY_MS)
  },

  dismiss() {
    if (this.dismissing) return
    this.dismissing = true
    clearTimeout(this.showTimer)
    this.el.classList.remove("iab-escape-popover-active")
    this.el.classList.add("iab-escape-popover-leaving")

    setTimeout(() => {
      this.pushEvent("iab_escape_dismiss", {})
    }, IAB_ESCAPE_CLOSE_MS)
  },

  destroyed() {
    clearTimeout(this.showTimer)
    if (this.backdrop && this.onBackdropClick) {
      this.backdrop.removeEventListener("click", this.onBackdropClick)
    }
    if (this.dismissButtons && this.onDismissClick) {
      this.dismissButtons.forEach((btn) =>
        btn.removeEventListener("click", this.onDismissClick)
      )
    }
  }
}

// Kept for any cached markup still referencing the old hook name.
Hooks.InAppEscapeDismissPersist = Hooks.InAppEscapePopover

// Multi-attempt iOS handoff to Safari. Meta's webviews on iOS 26.x+
// block single-shot `x-safari-https://` redirects, so we fire several
// variants in quick succession and watch the Page Visibility API. If
// the app still hasn't backgrounded after ~1500 ms we surface an
// inline hint that points the user at the webview's own "⋯ → Open in
// Browser" menu — the only 100%-reliable path on current Instagram.
//
// Android is intentionally NOT handled here; the server-side
// `intent://…;package=com.android.chrome;…` redirect still works
// reliably and doesn't need the multi-try dance.
Hooks.IabEscapeIos = {
  mounted() {
    this.clickHandler = (e) => {
      e.preventDefault()
      this.attempt()
    }
    this.el.addEventListener("click", this.clickHandler)
  },

  destroyed() {
    if (this.clickHandler) {
      this.el.removeEventListener("click", this.clickHandler)
    }
    this.cleanupVisibility()
    this.clearTimers()
  },

  attempt() {
    const url = this.el.dataset.canonicalUrl
    if (!url) return

    const stripped = url.replace(/^https?:\/\//, "")
    const xSafari = "x-safari-https://" + stripped
    const legacy = "com-apple-mobilesafari-tab:" + url

    this.escaped = false
    this.onVisibility = () => {
      if (document.hidden) this.escaped = true
    }
    document.addEventListener("visibilitychange", this.onVisibility)

    // Attempt 1 (t=0): direct href swap. Still works in older IG/FB,
    // Messenger, Threads, LinkedIn webviews.
    try { window.location.href = xSafari } catch (_e) {}

    // Attempt 2 (t=300): `window.open` variant. This briefly worked
    // around Meta's block around IG 418; some users on older app
    // versions will still land in Safari via this path.
    this.t2 = setTimeout(() => {
      if (this.escaped) return
      try { window.open(xSafari, "_blank") } catch (_e) {}
    }, 300)

    // Attempt 3 (t=700): legacy scheme for pre-iOS 17 devices.
    this.t3 = setTimeout(() => {
      if (this.escaped) return
      try { window.location.href = legacy } catch (_e) {}
    }, 700)

    // t=1500: give up and surface the manual "⋯ menu" hint. If the
    // app actually did background we skip this (user will come back
    // to the Qlink page already in Safari, no hint needed).
    this.tFail = setTimeout(() => {
      this.cleanupVisibility()
      if (this.escaped) return
      this.showFailHint()
    }, 1500)
  },

  showFailHint() {
    const id = this.el.dataset.failHintId
    if (!id) return
    const hint = document.getElementById(id)
    if (hint) hint.classList.remove("hidden")
  },

  cleanupVisibility() {
    if (this.onVisibility) {
      document.removeEventListener("visibilitychange", this.onVisibility)
      this.onVisibility = null
    }
  },

  clearTimers() {
    [this.t2, this.t3, this.tFail].forEach((t) => { if (t) clearTimeout(t) })
    this.t2 = this.t3 = this.tFail = null
  }
}

// AuthSheet: orchestrates the in-place auth completion handshake.
//
//   1. Receives `qadabra:finalize-auth` from the server with the signed
//      exchange token + CSRF token.
//   2. POSTs to /auth/finalize_session; the controller sets the session
//      cookie and returns 204.
//   3. On success, disconnects and reconnects the LiveSocket so the
//      re-mounted LV picks up `current_scope.user` and the modal
//      disappears by render condition.
//   4. 5-second watchdog: if the socket doesn't re-establish in time,
//      fall back to a full reload — graceful degradation lands the user
//      authed at the top of the page.
//
// US display `###-###-####` while typing. Server also formats, but
// LiveView will not overwrite a focused input's value on patch — this
// hook applies the mask immediately and keeps assigns in sync via
// `update_mobile` (same handler as before).
function formatUsPhoneDigits(digits) {
  const d = digits.replace(/\D/g, '').slice(0, 10)
  const len = d.length
  if (len === 0) return ''
  if (len <= 3) return d
  if (len <= 6) return d.slice(0, 3) + '-' + d.slice(3)
  return d.slice(0, 3) + '-' + d.slice(3, 6) + '-' + d.slice(6)
}

Hooks.AuthSheetPhone = {
  mounted() {
    this.onInput = (e) => {
      const el = e.target
      const formatted = formatUsPhoneDigits(el.value)
      if (el.value !== formatted) el.value = formatted
      const root = el.closest('[data-phx-component]')
      if (root && typeof this.pushEventTo === 'function') {
        this.pushEventTo(root, 'update_mobile', { value: formatted })
      } else {
        this.pushEvent('update_mobile', { value: formatted })
      }
    }
    this.el.addEventListener('input', this.onInput)
  },

  updated() {
    const attr = this.el.getAttribute('value')
    if (this.el !== document.activeElement && attr != null && this.el.value !== attr) {
      this.el.value = attr
    }
  },

  destroyed() {
    this.el.removeEventListener('input', this.onInput)
  }
}

// See docs/qlink_auth_refactor_plan.md §5.9.
Hooks.AuthFinalize = {
  mounted() {
    this.handleEvent("qadabra:finalize-auth", ({ token, csrf_token }) => {
      this.finalize(token, csrf_token)
    })
  },

  async finalize(token, csrfTokenOverride) {
    const csrf =
      csrfTokenOverride ||
      document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ||
      ""

    try {
      const res = await fetch("/auth/finalize_session", {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "x-csrf-token": csrf,
          Accept: "application/json"
        },
        body: JSON.stringify({ token })
      })

      if (res.status === 204) {
        this.reconnectSocket()
      } else {
        let reason = "unknown"
        try {
          const body = await res.json()
          reason = body.error || reason
        } catch (_e) {
          // non-JSON body; ignore
        }
        this.pushEventTo(this.el, "auth:finalize_failed", { reason })
      }
    } catch (err) {
      console.warn("[AuthFinalize] fetch failed", err)
      this.pushEventTo(this.el, "auth:finalize_failed", { reason: "network" })
    }
  },

  reconnectSocket() {
    const socket = window.liveSocket
    if (!socket) {
      window.location.reload()
      return
    }

    // Watchdog: if the socket doesn't come back online within 5s, do a
    // full reload so the user still lands authed.
    const timeout = setTimeout(() => window.location.reload(), 5000)

    // phoenix's Socket exposes an onOpen listener via `.socket.onOpen/1`;
    // liveSocket wraps it but doesn't currently expose a matching API,
    // so probe the underlying socket directly.
    const rawSocket = typeof socket.socket === "function" ? socket.socket() : socket.socket

    if (rawSocket && typeof rawSocket.onOpen === "function") {
      rawSocket.onOpen(() => clearTimeout(timeout))
    }

    socket.disconnect()
    socket.connect()
  }
}

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
      // Anon READY pill uses infinite bg pulse; `.wallet-pulse` sets `animation` and would
      // replace that shorthand after LiveView patches if we applied it here.
      const anonStrobe = this.el.classList.contains('wallet-strip-anon-focus')
      if (!anonStrobe) {
        this.el.classList.remove('wallet-pulse')
        void this.el.offsetWidth
        this.el.classList.add('wallet-pulse')
      }

      // Play coin sound only when balance increases, sounds enabled, and not recently played
      // Use a global debounce to prevent multiple components from playing simultaneously
      const now = Date.now()
      const lastPlayed = window.walletSoundLastPlayed || 0
      
      if (
        !anonStrobe &&
        newBalanceNum > this.lastBalanceNum &&
        this.isSoundEnabled() &&
        now - lastPlayed > 500
      ) {
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

    this.pushTargeted(this.updateEvent, {
      month: month,
      day: day,
      year: year
    })
  },

  // Route to the nearest LiveComponent if embedded in one; otherwise
  // fall through to the root LiveView. Mirrors OTPInput so this hook
  // can be reused from AuthSheet (component) without a parent forward.
  pushTargeted(event, payload) {
    const component = this.el.closest('[data-phx-component]')
    if (component) {
      this.pushEventTo(component, event, payload)
    } else {
      this.pushEvent(event, payload)
    }
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
    this.widgetTheme = this.el.dataset.widgetTheme === 'true'
    this.ringActive = this.widgetTheme ? 'ring-widget-700' : 'ring-primary'

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
      
      // Route to the nearest LiveComponent if embedded in one; otherwise
      // fall through to the root LiveView. Lets this hook be reused from
      // AuthSheet (component) without forcing the parent LV to forward.
      this.pushTargeted(this.updateEvent, { verification_code: value })
      
      // Auto-submit when complete
      if (value.length === this.length) {
        this.pushTargeted(this.verifyEvent, { code: value })
      }
    })
    
    // Handle focus - highlight active slot
    this.input.addEventListener('focus', () => {
      this.updateActiveSlot()
    })
    
    this.input.addEventListener('blur', () => {
      this.clearSlotRings()
    })
    
    // Update active slot on selection change
    this.input.addEventListener('keyup', () => this.updateActiveSlot())
    this.input.addEventListener('click', () => this.updateActiveSlot())
    
    // No auto-focus - user tap triggers autofill reliably
    // The pulsing first slot draws attention to tap
  },
  
  pushTargeted(event, payload) {
    const component = this.el.closest('[data-phx-component]')
    if (component) {
      this.pushEventTo(component, event, payload)
    } else {
      this.pushEvent(event, payload)
    }
  },

  updateSlots(value) {
    const chars = value.split('')
    this.slots.forEach((slot, i) => {
      slot.textContent = chars[i] || ''
    })
    this.updateActiveSlot()
  },
  
  clearSlotRings() {
    this.slots.forEach(slot =>
      slot.classList.remove('ring-2', 'ring-primary', 'ring-widget-700')
    )
  },

  updateActiveSlot() {
    const pos = Math.min(this.input.value.length, this.length - 1)
    this.slots.forEach((slot, i) => {
      if (i === pos && document.activeElement === this.input) {
        slot.classList.add('ring-2', this.ringActive)
      } else {
        slot.classList.remove('ring-2', 'ring-primary', 'ring-widget-700')
      }
    })
  },
  
  // Handle server-side updates (e.g., clear on error)
  updated() {
    this.widgetTheme = this.el.dataset.widgetTheme === 'true'
    this.ringActive = this.widgetTheme ? 'ring-widget-700' : 'ring-primary'

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
  const registerPwaServiceWorker = () => {
    let swReloading = false

    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (swReloading) return
      swReloading = true
      window.location.reload()
    })

    navigator.serviceWorker.register("/service-worker.js", { updateViaCache: "none" })
      .then((registration) => {
        console.log("✅ Service Worker registered:", registration.scope)

        const activateWaitingWorker = () => {
          if (registration.waiting) {
            registration.waiting.postMessage({ type: "SKIP_WAITING" })
          }
        }

        registration.addEventListener("updatefound", () => {
          const worker = registration.installing
          if (!worker) return

          worker.addEventListener("statechange", () => {
            if (worker.state === "installed" && navigator.serviceWorker.controller) {
              activateWaitingWorker()
            }
          })
        })

        activateWaitingWorker()
        registration.update().catch(() => {})

        document.addEventListener("visibilitychange", () => {
          if (document.visibilityState === "visible") {
            registration.update().catch(() => {})
          }
        })
      })
      .catch((error) => {
        console.error("❌ Service Worker registration failed:", error)
      })
  }

  window.addEventListener("load", registerPwaServiceWorker)
} else if (isExtension) {
  console.log("🚫 Service Worker disabled in extension context (skip register; do NOT unregister - unregister can trigger reload loop)")
} else {
  console.warn("❌ Service Worker not supported in this browser")
}

