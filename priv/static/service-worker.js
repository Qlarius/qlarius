// Version: 1.0.4 - Bypass HTTP cache for /assets/ in PWA; keep referral cache isolated
const SW_VERSION = "1.0.4"
const REFERRAL_CACHE = "qadabra-shared-data"
const REFERRAL_CODE_ENDPOINT = "/_shared/referral-code"

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys()
      await Promise.all(
        keys
          .filter((key) => key !== REFERRAL_CACHE)
          .map((key) => caches.delete(key))
      )
      await self.clients.claim()
      const clients = await self.clients.matchAll({ type: "window" })
      for (const client of clients) {
        client.postMessage({ type: "APP_UPDATED", version: SW_VERSION })
      }
    })()
  )
})

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting()
  }
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  const url = new URL(request.url)

  if (url.pathname === REFERRAL_CODE_ENDPOINT) {
    if (request.method === "POST") {
      event.respondWith(
        request.json().then((body) => {
          return caches.open(REFERRAL_CACHE).then((cache) => {
            const response = new Response(JSON.stringify(body))
            cache.put(REFERRAL_CODE_ENDPOINT, response.clone())
            return new Response(JSON.stringify({ success: true }))
          })
        }).catch((err) => {
          return new Response(JSON.stringify({ error: err.message }), { status: 500 })
        })
      )
      return
    }

    if (request.method === "GET") {
      event.respondWith(
        caches.open(REFERRAL_CACHE).then((cache) => {
          return cache.match(REFERRAL_CODE_ENDPOINT).then((response) => {
            return response || new Response(JSON.stringify({}))
          })
        }).catch(() => {
          return new Response(JSON.stringify({}))
        })
      )
      return
    }
  }

  // Let the browser handle navigations (fresh HTML with current digested asset URLs).
  if (event.request.mode === "navigate") {
    return
  }

  // PWAs cache /assets/* aggressively; always hit the network for JS/CSS bundles.
  const isAsset =
    url.pathname.startsWith("/assets/") ||
    url.pathname === "/service-worker.js"

  event.respondWith(
    fetch(request, isAsset ? { cache: "no-store" } : undefined).catch(() => {
      return new Response("Network error", { status: 408, statusText: "Request Timeout" })
    })
  )
})

self.addEventListener("push", (event) => {
  console.log("Push notification received:", event)
  console.log("Push event.data:", event.data)

  let data = {}
  try {
    if (event.data) {
      console.log("Raw data text:", event.data.text())
      data = event.data.json()
      console.log("Parsed notification data:", data)
    }
  } catch (error) {
    console.error("Error parsing push data:", error)
  }

  const options = {
    body: data.body || "You have new ads available",
    icon: data.icon || "/images/qadabra_app_icon_192.png",
    badge: data.badge || "/images/qadabra_app_icon_192.png",
    data: data.data || {},
    tag: "ad-notification",
    requireInteraction: false,
    actions: [
      { action: "open", title: "View" },
      { action: "close", title: "Dismiss" }
    ]
  }

  console.log("Showing notification with title:", data.title || "Sponser here")
  console.log("Notification options:", options)

  event.respondWith(
    Promise.all([
      self.registration.showNotification(data.title || "Sponser here", options)
        .then(() => {
          console.log("✅ Notification shown successfully!")
        })
        .catch((error) => {
          console.error("❌ Error showing notification:", error)
          console.error("Error name:", error.name)
          console.error("Error message:", error.message)
        }),
      updateBadge(data.data?.unread_count)
    ])
  )
})

self.addEventListener("notificationclick", (event) => {
  console.log("Notification clicked:", event.action)
  event.notification.close()

  if (event.action === "close") {
    return
  }

  const url = event.notification.data?.url || "/ads"

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true })
      .then(clientList => {
        for (const client of clientList) {
          if (client.url.includes(url) && "focus" in client) {
            return client.focus()
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(url).then(client => {
            clearBadge()

            fetch("/api/push/track-click", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ url })
            })
          })
        }
      })
  )
})

async function updateBadge(count) {
  if (!count || count === 0) {
    return clearBadge()
  }

  if ("setAppBadge" in navigator) {
    try {
      await navigator.setAppBadge(count)
    } catch (error) {
      console.error("Failed to set badge:", error)
    }
  }
}

async function clearBadge() {
  if ("clearAppBadge" in navigator) {
    try {
      await navigator.clearAppBadge()
    } catch (error) {
      console.error("Failed to clear badge:", error)
    }
  }
}
