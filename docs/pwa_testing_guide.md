# PWA Testing Guide for Local Development

This guide covers how to test PWA functionality on your development laptop without needing to push to production first.

---

## Quick Reference

| Method | Best For | Setup Time | Accuracy |
|--------|----------|------------|----------|
| Chrome DevTools | Quick iteration, manifest/SW checks | 0 min | Medium |
| iOS Simulator | iOS install flow, Safari testing | 5 min | High |
| Android Emulator | Android install, notifications | 10 min | High |
| Desktop PWA | Basic functionality, quick checks | 0 min | Low (desktop only) |
| Remote Debugging | Real device + laptop DevTools | 2 min | Highest |

---

## Option 1: Chrome DevTools (Desktop) ⭐ Easiest

Chrome has excellent PWA testing tools built-in.

### Setup
```bash
# Start Phoenix server
mix phx.server

# Open Chrome/Edge
open http://localhost:4000

# Open DevTools
# Mac: Cmd+Option+I
# Windows: F12
```

### What You Can Test
- ✅ Manifest validation (icon, name, colors)
- ✅ Service Worker registration
- ✅ Install prompt trigger
- ✅ Desktop PWA installation
- ✅ Push notification subscription
- ✅ Offline mode
- ✅ Cache Storage

### Trigger Install Prompt
1. DevTools → Application → Manifest → "Add to shelf" link
2. Or: Chrome address bar → Install icon (⊕)
3. Or: Three dots menu → "Install Qlarius..."

### Test Notifications
```javascript
// In DevTools Console
Notification.requestPermission().then(perm => {
  if (perm === 'granted') {
    new Notification('Test from DevTools', {
      body: 'PWA notifications working!',
      icon: '/images/qadabra_icon.png'
    })
  }
})
```

### Simulate Mobile Device
```bash
# In DevTools
1. Toggle Device Toolbar (Cmd+Shift+M)
2. Select iPhone/Android device from dropdown
3. Test responsive layout

# Limitation: Won't show iOS-specific install flow
```

### Test iOS Install Guide (Simulated)
```javascript
// In Console, override user agent
Object.defineProperty(navigator, 'userAgent', {
  get: function() {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'
  }
})

// Refresh page
// Verify iOS banner and modal appear
```

---

## Option 2: iOS Simulator (Mac Only) ⭐ Most Accurate for iOS

Test the real iOS PWA experience using Xcode's iOS Simulator.

### Initial Setup (One-Time)
```bash
# Install Xcode from App Store (if not already installed)

# Or install command line tools
xcode-select --install

# Launch simulator
open -a Simulator

# Or from Xcode:
# Xcode → Open Developer Tool → Simulator
```

### Access Your Local Server from Simulator

**Problem**: Simulator can't access `localhost` directly

**Solution 1 - Use your Mac's Local IP:**
```bash
# Find your local IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Example output: inet 192.168.1.147

# In Simulator Safari, navigate to:
http://192.168.1.147:4000
```

**Solution 2 - ngrok (Recommended for HTTPS):**
```bash
# Install ngrok
brew install ngrok

# Sign up for free account: https://dashboard.ngrok.com/signup
# Get your auth token from dashboard

# Authenticate (one-time)
ngrok config add-authtoken YOUR_TOKEN_HERE

# Start tunnel (in separate terminal)
ngrok http 4000

# Output shows:
# Forwarding  https://abc123.ngrok.io -> http://localhost:4000

# Use the HTTPS URL in Simulator Safari
```

### Testing in iOS Simulator

#### Install Flow
1. Open **Safari** in simulator
2. Navigate to your local IP or ngrok URL
3. Login to Qlarius
4. Wait for install banner to appear
5. Tap **"Install App"** button
6. Verify modal appears with 3-step instructions
7. Tap **Share** button (box with arrow up) at bottom center
8. Scroll and tap **"Add to Home Screen"**
9. Edit name if desired, tap **"Add"**
10. App icon appears on home screen
11. Tap icon → Opens in standalone mode (full-screen)

#### What You Can Test
- ✅ Real iOS PWA install flow
- ✅ Your custom iOS install guide modal
- ✅ Standalone mode (full-screen)
- ✅ iOS-specific manifest behavior
- ✅ Safari rendering quirks
- ✅ Safe area handling
- ✅ Status bar styling
- ⚠️ Push notifications (limited in simulator)

#### Limitations
- Simulator doesn't perfectly replicate device performance
- Some iOS-specific features may behave differently
- Notifications are unreliable in simulator
- No Face ID/Touch ID testing

#### Useful Simulator Shortcuts
```
Cmd+Shift+H       - Home button
Cmd+Shift+H+H     - App switcher
Cmd+L             - Lock/sleep
Cmd+Right/Left    - Rotate device
Cmd+1/2/3         - Scale (50%, 75%, 100%)
```

---

## Option 3: Android Emulator ⭐ Good for Android Testing

### Initial Setup (One-Time)
```bash
# Install Android Studio
# Download from: https://developer.android.com/studio
# Or via Homebrew:
brew install --cask android-studio

# After installation:
1. Open Android Studio
2. Tools → AVD Manager (Android Virtual Device)
3. Click "Create Virtual Device"
4. Select device: Pixel 7 or Pixel 7 Pro
5. Select system image: Latest Android (API 34+)
   - Make sure it has "Play Store" support
6. Click "Finish"
7. Click green "Play" button to start emulator
```

### Access Local Server from Emulator

Android emulator provides special network aliases:

**Option 1 - Special Localhost Alias:**
```
http://10.0.2.2:4000
# This maps to your host machine's localhost:4000
```

**Option 2 - Your Mac's IP:**
```bash
# Find your local IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Use in emulator
http://192.168.1.147:4000
```

**Option 3 - ngrok (Best for HTTPS):**
```bash
# Same setup as iOS Simulator
ngrok http 4000

# Use the HTTPS URL in emulator Chrome
https://abc123.ngrok.io
```

### Testing in Android Emulator

#### Install Flow (Automatic)
1. Open **Chrome** in emulator
2. Navigate to `http://10.0.2.2:4000` or ngrok URL
3. Login to Qlarius
4. Chrome automatically shows mini-infobar at bottom
5. Or wait for your custom banner to appear
6. Tap "Install" on banner
7. Native prompt appears: "Add Qlarius to Home screen?"
8. Tap "Install" or "Add"
9. App appears on home screen and in app drawer

#### Install Flow (Manual)
1. Open Chrome in emulator
2. Navigate to Qlarius
3. Tap three dots menu (⋮) in top right
4. Tap "Install app" or "Add to Home screen"
5. Confirm installation

#### What You Can Test
- ✅ `beforeinstallprompt` event firing
- ✅ One-click install flow
- ✅ Your custom install banner
- ✅ Android install guide modal
- ✅ Full PWA features
- ✅ Push notifications (with some setup)
- ✅ Background sync
- ✅ App shortcuts
- ✅ Badge updates

#### Advantages Over iOS
- One-click install via native prompt
- Web Push works in browser + PWA
- Better DevTools integration
- More PWA features supported

---

## Option 4: Desktop PWA Installation (Quick Test)

Install Qlarius as a desktop PWA for quick functional testing.

### Chrome/Edge (Mac/Windows/Linux)
```bash
# Start server
mix phx.server

# Visit in Chrome/Edge
http://localhost:4000

# Login

# Install via:
1. Click install icon (⊕) in address bar
2. Or: Three dots → "Install Qlarius..."
3. Or: DevTools → Application → Manifest → Install

# App opens in dedicated window
# Icon added to:
# - macOS: Applications folder + Dock
# - Windows: Start Menu + Desktop
# - Linux: App launcher
```

### What You Can Test
- ✅ Manifest parsing and validation
- ✅ Icon rendering (all sizes)
- ✅ Theme colors (title bar)
- ✅ Standalone window behavior
- ✅ Desktop notifications
- ✅ Service worker caching
- ✅ Offline functionality
- ❌ Mobile-specific UI/UX
- ❌ iOS/Android install flows
- ❌ Touch interactions

### Quick Validation Checklist
```
□ App installs without errors
□ Window opens in standalone mode
□ App icon displays correctly
□ Theme color matches branding
□ Notifications permission prompts
□ Offline mode works
□ Service worker registers
□ No console errors
```

---

## Option 5: Remote Debugging (Real Device to Laptop) ⭐ Best of Both Worlds

Test on your actual phone while debugging from your laptop.

### For Android Devices

#### Setup (One-Time)
```bash
# 1. Enable USB Debugging on Android phone:
#    a. Settings → About Phone
#    b. Tap "Build Number" 7 times (becomes developer)
#    c. Settings → Developer Options
#    d. Enable "USB Debugging"
#    e. Enable "USB Debugging (Security Settings)" if available

# 2. Connect phone to Mac via USB cable

# 3. Phone will prompt "Allow USB debugging?"
#    Check "Always allow" and tap "OK"
```

#### Start Debugging Session
```bash
# Terminal 1: Start Phoenix
mix phx.server

# Terminal 2: Start ngrok (for HTTPS)
ngrok http 4000

# On Android phone:
1. Open Chrome
2. Navigate to ngrok HTTPS URL
3. Login to Qlarius

# On Mac in Chrome:
1. Visit: chrome://inspect
2. Your phone should appear under "Remote Target"
3. Find your Qlarius tab
4. Click "inspect" button

# DevTools window opens on Mac
# - Console logs from phone appear on Mac
# - Inspect elements on phone from Mac
# - Network tab shows phone's requests
# - Test PWA features with full DevTools
```

#### What You Can Debug
- ✅ Real device performance
- ✅ Actual network conditions
- ✅ Touch interactions
- ✅ Device-specific issues
- ✅ Service worker behavior
- ✅ Real notifications
- ✅ Full DevTools on laptop

### For iOS Devices

#### Setup (One-Time)
```bash
# 1. On iPhone/iPad:
#    Settings → Safari → Advanced
#    Enable "Web Inspector"

# 2. On Mac:
#    Safari → Preferences → Advanced
#    Check "Show Develop menu in menu bar"
```

#### Start Debugging Session
```bash
# Terminal: Start ngrok
ngrok http 4000

# On iPhone:
1. Open Safari
2. Navigate to ngrok HTTPS URL
3. Login to Qlarius

# On Mac Safari:
1. Menu bar → Develop → [Your iPhone Name]
2. Select your Qlarius tab
3. Web Inspector opens

# Web Inspector shows:
# - Console logs
# - Network requests
# - Element inspection
# - Storage inspection
```

#### Limitations
- iOS Web Inspector is less feature-rich than Chrome DevTools
- Can't modify CSS in real-time as easily
- Some features hidden or different locations

---

## ngrok Setup (Highly Recommended)

ngrok gives you HTTPS locally, which unlocks all PWA features.

### Why You Need HTTPS
- **Required** for Service Workers
- **Required** for Push Notifications
- **Required** for many modern web APIs
- **Best practice** for PWA testing
- **Works** across all devices on any network

### Installation & Setup
```bash
# Install via Homebrew
brew install ngrok

# Sign up for free account
# Visit: https://dashboard.ngrok.com/signup

# Get your auth token from dashboard
# Visit: https://dashboard.ngrok.com/get-started/your-authtoken

# Authenticate (one-time)
ngrok config add-authtoken YOUR_TOKEN_HERE

# Verify installation
ngrok version
```

### Usage
```bash
# Start Phoenix server (Terminal 1)
mix phx.server

# Start ngrok tunnel (Terminal 2)
ngrok http 4000

# Output shows:
Session Status                online
Account                       your@email.com
Version                       3.x.x
Region                        United States (us)
Forwarding                    https://abc123.ngrok-free.app -> http://localhost:4000

# Use the HTTPS URL (https://abc123.ngrok-free.app) for all testing
```

### Benefits
- ✅ Real HTTPS with valid certificate
- ✅ Works on any device, any network
- ✅ Stable URL during session
- ✅ Share with teammates
- ✅ Works with iOS Simulator, Android Emulator, real devices
- ✅ Free tier sufficient for testing
- ✅ No firewall/router configuration needed

### Free Tier Limitations
- URL changes each time you restart ngrok
- 40 connections/minute limit (plenty for testing)
- Banner on free URLs (doesn't affect PWA testing)

### Pro Tips
```bash
# Custom subdomain (requires paid plan)
ngrok http 4000 --subdomain=qlarius-dev

# Inspect traffic
# Visit: http://localhost:4040
# Shows all requests/responses through tunnel

# Save config for reuse
# Edit: ~/.config/ngrok/ngrok.yml
tunnels:
  qlarius:
    proto: http
    addr: 4000
    
# Then run:
ngrok start qlarius
```

---

## DevTools PWA Checklist

When testing PWA in Chrome DevTools, verify:

### Application → Manifest
```
□ name: "Qlarius"
□ short_name: "Qlarius"
□ description: present and accurate
□ icons: 192x192, 512x512 (PNG)
□ start_url: "/"
□ display: "standalone"
□ orientation: "portrait" or "any"
□ theme_color: matches branding
□ background_color: matches branding
□ scope: "/"
```

### Application → Service Workers
```
□ Service worker registered
□ Status: "activated and is running"
□ Scope: "/"
□ Update on reload (enabled for dev)
□ No errors in console
□ Fetch events working
```

### Application → Storage
```
□ Cache Storage populated
□ Caches named appropriately
□ Critical assets cached
□ IndexedDB (if using)
```

### Console (No Errors)
```
□ No service worker errors
□ No manifest parsing errors
□ No 404s for icons
□ PWA hook logs appearing:
  - "PWA install prompt available" (Android)
  - Device detection logs
```

### Network Tab
```
□ Service worker intercepts requests
□ Cached resources served from SW
□ No excessive network calls
```

### Lighthouse Audit
```
# Run Lighthouse PWA audit
DevTools → Lighthouse → Progressive Web App → Analyze

Target scores:
□ PWA score: 90+
□ All PWA criteria passing:
  □ Installable
  □ Works offline
  □ HTTPS
  □ Fast page load
  □ Configured for custom splash screen
```

---

## Testing Your Specific Implementation

### Test iOS Install Banner & Guide

#### In Chrome DevTools (Simulated)
```bash
# 1. Open DevTools (Cmd+Option+I)
# 2. Toggle Device Toolbar (Cmd+Shift+M)
# 3. Select "iPhone 14 Pro" from device list
# 4. In Console, simulate iOS Safari:

Object.defineProperty(navigator, 'userAgent', {
  get: function() {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
  }
})

# 5. Refresh page
# 6. Verify:
#    - iOS install banner appears at bottom
#    - Banner has correct messaging
#    - "Install App" button present
# 7. Click "Install App"
# 8. Verify modal appears with:
#    - 3-step instructions
#    - Share button icon
#    - "Add to Home Screen" text
#    - Visual illustrations
```

#### In iOS Simulator (Real Test)
```bash
# 1. Start ngrok
ngrok http 4000

# 2. Open iOS Simulator
open -a Simulator

# 3. In Simulator Safari, navigate to ngrok URL
# 4. Login to Qlarius
# 5. Wait 3 seconds
# 6. Verify banner slides up from bottom
# 7. Tap "Install App"
# 8. Verify modal displays correctly
# 9. Follow actual install process
# 10. Verify PWA launches in standalone mode
```

### Test Android Install Banner & Prompt

#### In Chrome Desktop
```bash
# 1. Start Phoenix
mix phx.server

# 2. Open Chrome, visit http://localhost:4000
# 3. Open DevTools Console
# 4. Look for log: "PWA install prompt available"
# 5. Verify your banner appears (or native prompt)
# 6. Click "Install App" on your banner
# 7. Verify native prompt appears
# 8. Click "Install" in native prompt
# 9. Verify app installs to system
```

#### In Android Emulator
```bash
# 1. Start ngrok
ngrok http 4000

# 2. Start Android Emulator
# 3. Open Chrome in emulator
# 4. Navigate to ngrok URL
# 5. Login
# 6. Chrome shows mini-infobar automatically
# 7. Your banner should also appear
# 8. Tap "Install App" on banner
# 9. Native prompt: "Add Qlarius to Home screen?"
# 10. Tap "Install"
# 11. App appears on home screen
```

### Test Dismissal Logic

#### Manual Database Update
```elixir
# In IEx (iex -S mix)
user = Qlarius.Repo.get(Qlarius.Accounts.User, YOUR_USER_ID)

user
|> Ecto.Changeset.change(%{
  pwa_install_dismissed_at: DateTime.utc_now()
})
|> Qlarius.Repo.update()

# Refresh browser
# Verify banner does NOT appear
```

#### Test 7-Day Cooldown
```elixir
# Set dismissal to 6 days ago
user
|> Ecto.Changeset.change(%{
  pwa_install_dismissed_at: DateTime.add(DateTime.utc_now(), -6, :day)
})
|> Qlarius.Repo.update()

# Refresh - banner should NOT show (within 7 days)

# Set dismissal to 8 days ago
user
|> Ecto.Changeset.change(%{
  pwa_install_dismissed_at: DateTime.add(DateTime.utc_now(), -8, :day)
})
|> Qlarius.Repo.update()

# Refresh - banner SHOULD show (past 7 day cooldown)
```

### Test Installation Success Tracking

#### Mark as Installed
```javascript
// In DevTools Console
// Simulate app installed event
window.dispatchEvent(new Event('appinstalled'))

// Or manually trigger via LiveView
liveSocket.execJS(document.querySelector('[phx-hook="PWAInstall"]'), 
  [["push", {"event": "pwa_installed", "value": {}}]])
```

#### Verify Database Update
```elixir
# In IEx
user = Qlarius.Repo.get(Qlarius.Accounts.User, YOUR_USER_ID)
user.pwa_installed
# Should be: true

user.pwa_installed_at
# Should be: ~U[2026-01-06 21:05:42.123456Z] (recent timestamp)
```

### Test Platform Detection

#### Simulate Different Platforms
```javascript
// In DevTools Console

// Test iOS detection
Object.defineProperty(navigator, 'userAgent', {
  get: () => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15'
})
Object.defineProperty(navigator, 'standalone', {
  get: () => false
})

// Test Android detection
Object.defineProperty(navigator, 'userAgent', {
  get: () => 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
})

// Test PWA mode (already installed)
Object.defineProperty(navigator, 'standalone', {
  get: () => true
})
// Or
window.matchMedia = (query) => {
  if (query === '(display-mode: standalone)') {
    return { matches: true }
  }
}

// Refresh and verify correct banner shows
```

---

## Recommended Testing Workflow

### Phase 1: Quick Desktop Validation (5 minutes)
```bash
# Terminal 1
mix phx.server

# Terminal 2 (optional, for HTTPS)
ngrok http 4000

# Browser
1. Visit localhost:4000 or ngrok URL
2. F12 → Application tab
3. Check Manifest (no errors)
4. Check Service Worker (registered)
5. Test install from address bar
6. Verify notifications permission
7. Test offline mode (DevTools → Network → Offline)
```

**Pass Criteria:**
- ✅ No manifest errors
- ✅ Service worker active
- ✅ Can install as desktop app
- ✅ No console errors

### Phase 2: Mobile Layout Check (5 minutes)
```bash
# In Chrome DevTools
1. Toggle Device Toolbar (Cmd+Shift+M)
2. Select iPhone 14 Pro
3. Test responsive layout
4. Verify banner positioning
5. Test modal appearance
6. Check touch target sizes (44x44px minimum)
```

**Pass Criteria:**
- ✅ Banner appears at bottom, above dock
- ✅ Modal displays correctly
- ✅ All buttons tappable
- ✅ Text readable
- ✅ No layout overflow

### Phase 3: iOS Simulator Test (15 minutes)
```bash
# First time only
1. Set up iOS Simulator
2. Set up ngrok

# Each test
1. ngrok http 4000
2. Open Simulator
3. Safari → Navigate to ngrok URL
4. Login
5. Test full iOS install flow
6. Verify standalone mode
7. Test app functionality
```

**Pass Criteria:**
- ✅ Banner appears after 3 seconds
- ✅ iOS guide modal accurate
- ✅ Can complete install process
- ✅ App runs in standalone mode
- ✅ Status bar styled correctly
- ✅ Safe areas handled correctly

### Phase 4: Android Emulator Test (15 minutes)
```bash
# First time only
1. Set up Android Emulator
2. Set up ngrok

# Each test
1. ngrok http 4000
2. Start Android Emulator
3. Chrome → Navigate to ngrok URL
4. Login
5. Test beforeinstallprompt
6. Test install flow
7. Verify app functionality
```

**Pass Criteria:**
- ✅ beforeinstallprompt fires
- ✅ Banner triggers native prompt
- ✅ Install completes successfully
- ✅ App in home screen + app drawer
- ✅ Standalone mode works
- ✅ Notifications work

### Phase 5: Real Device Final Check (10 minutes)
```bash
# Before any production push
1. Deploy to staging OR use ngrok
2. Test on your actual iPhone
3. Test on actual Android device (if available)
4. Verify all features work as expected
5. Check performance on real network
```

**Pass Criteria:**
- ✅ Install flow smooth on real device
- ✅ Performance acceptable
- ✅ No unexpected behaviors
- ✅ Notifications work
- ✅ Offline mode works

### Daily Development Workflow
```bash
# Quick iteration (most common)
mix phx.server
# → Test in Chrome DevTools with mobile viewport
# → ~2 minute feedback loop

# Feature complete
# → Test in iOS Simulator
# → ~10 minute validation

# Pre-commit
# → Full desktop + simulator suite
# → ~20 minutes

# Pre-deploy
# → Add real device testing
# → ~30 minutes total
```

---

## Troubleshooting Common Issues

### Service Worker Not Registering

**Symptoms:**
- DevTools shows no service worker
- Install prompt never appears
- Offline mode doesn't work

**Solutions:**
```bash
# 1. Check service worker file exists
ls priv/static/sw.js

# 2. Check it's being served
curl http://localhost:4000/sw.js

# 3. Verify registration in app.js
# Should have:
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js')
}

# 4. Check scope
# Service worker scope must include start_url

# 5. Clear old service workers
# DevTools → Application → Service Workers → Unregister
```

### Manifest Errors

**Symptoms:**
- Can't install PWA
- Wrong icon displays
- Theme color not applied

**Solutions:**
```bash
# 1. Validate manifest
# DevTools → Application → Manifest
# Look for errors or warnings

# 2. Check manifest is served
curl http://localhost:4000/manifest.webmanifest

# 3. Verify icons exist
ls priv/static/images/icons/

# 4. Check icon paths in manifest
# Must be absolute paths from root
"icons": [
  {
    "src": "/images/icons/icon-192x192.png",
    "sizes": "192x192",
    "type": "image/png"
  }
]

# 5. Clear browser cache
# DevTools → Application → Clear storage → Clear site data
```

### Install Prompt Not Appearing

**Symptoms:**
- Banner never shows
- beforeinstallprompt doesn't fire

**Solutions:**
```bash
# 1. Check PWA criteria met
# DevTools → Lighthouse → Run PWA audit
# Must pass all installability checks

# 2. Verify HTTPS (or localhost)
# http://localhost:4000 ✅
# https://abc123.ngrok.io ✅
# http://192.168.1.147:4000 ❌ (need HTTPS)

# 3. Check if already installed
# Browser won't prompt if PWA already installed

# 4. Check dismissal tracking
# If user dismissed recently, won't show for 7 days

# 5. Verify manifest has start_url
"start_url": "/"

# 6. Test manually
# Chrome: Three dots → "Install Qlarius..."
```

### iOS Simulator Issues

**Symptoms:**
- Can't access localhost
- Install doesn't work
- Notifications don't work

**Solutions:**
```bash
# 1. Use ngrok for HTTPS
ngrok http 4000
# Always use the HTTPS URL

# 2. Use Mac's IP, not localhost
ifconfig | grep "inet " | grep -v 127.0.0.1

# 3. Reset simulator
# Device → Erase All Content and Settings

# 4. Check Web Inspector enabled
# iOS Settings → Safari → Advanced → Web Inspector

# 5. Notifications limited in simulator
# Test on real device for notifications
```

### Android Emulator Issues

**Symptoms:**
- Can't access localhost
- Install prompt doesn't appear

**Solutions:**
```bash
# 1. Use 10.0.2.2 instead of localhost
http://10.0.2.2:4000

# 2. Or use ngrok
ngrok http 4000

# 3. Check Play Store enabled
# Must use system image with Play Store
# Recreate AVD if needed

# 4. Enable USB debugging in emulator
# Settings → About phone → Tap Build 7 times
# Settings → Developer options → USB debugging

# 5. Clear Chrome data
# Settings → Apps → Chrome → Storage → Clear data
```

### beforeinstallprompt Not Firing

**Symptoms:**
- Console never logs "PWA install prompt available"
- Can't trigger custom install button

**Possible Causes:**
```bash
# 1. Not on Android/Chrome
# Event only fires on Android Chrome/Edge

# 2. HTTPS not used
# Must be HTTPS (except localhost)

# 3. PWA criteria not met
# Run Lighthouse PWA audit

# 4. Already installed
# Uninstall PWA first

# 5. User previously dismissed
# Clear Chrome data or wait 3 months

# 6. Manifest invalid
# Check DevTools → Application → Manifest

# Test manually:
# Three dots → Install app
# If this works, event should fire
```

---

## Best Practices

### Development
- ✅ Always test with HTTPS (use ngrok)
- ✅ Test on multiple devices/platforms
- ✅ Run Lighthouse PWA audit regularly
- ✅ Test offline mode
- ✅ Verify service worker updates correctly
- ✅ Test install → uninstall → reinstall flow
- ✅ Check performance on slow network (DevTools → Network → Slow 3G)

### Before Deploying
- ✅ Full test suite on simulators
- ✅ Test on at least one real device
- ✅ Lighthouse score 90+
- ✅ No console errors
- ✅ All icons display correctly
- ✅ Theme colors applied
- ✅ Offline mode works
- ✅ Notifications permission handled gracefully

### Continuous Testing
- ✅ Test after any manifest changes
- ✅ Test after service worker updates
- ✅ Test after icon updates
- ✅ Regression test install flow monthly
- ✅ Monitor real user install rates

---

## Quick Command Reference

```bash
# Start development environment
mix phx.server                              # Phoenix server
ngrok http 4000                             # HTTPS tunnel

# Simulators
open -a Simulator                           # iOS Simulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34  # Android

# Find your local IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test service worker
curl http://localhost:4000/sw.js
curl http://localhost:4000/manifest.webmanifest

# IEx testing
iex -S mix
user = Qlarius.Repo.get(Qlarius.Accounts.User, 1)
user.pwa_installed

# Chrome DevTools
chrome://inspect                            # Android remote debugging
chrome://serviceworker-internals            # All service workers
```

---

## Resources

### Documentation
- [MDN PWA Guide](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps)
- [web.dev PWA Training](https://web.dev/progressive-web-apps/)
- [Chrome DevTools PWA](https://developer.chrome.com/docs/devtools/progressive-web-apps/)
- [iOS PWA Support](https://webkit.org/blog/8209/progressive-web-apps-for-ios/)

### Tools
- [ngrok](https://ngrok.com/) - HTTPS tunneling
- [Lighthouse](https://developers.google.com/web/tools/lighthouse) - PWA auditing
- [PWA Builder](https://www.pwabuilder.com/) - Validation and tips

### Testing
- [iOS Simulator Guide](https://developer.apple.com/documentation/safari-developer-tools/adding-a-web-app-to-the-home-screen)
- [Android Emulator Setup](https://developer.android.com/studio/run/managing-avds)
- [Remote Debugging iOS](https://webkit.org/web-inspector/enabling-web-inspector/)
- [Remote Debugging Android](https://developer.chrome.com/docs/devtools/remote-debugging/)

---

**End of PWA Testing Guide**

*For PWA implementation details, see: `docs/push_notifications_recommendations.md` (PWA Installation Guide section)*

