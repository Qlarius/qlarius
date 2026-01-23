// Version: 1.0.2 - Skip service worker in extension contexts
// Don't run service worker if we detect extension/iframe context
self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener("fetch", (event) => {
  // Just pass through all requests without modification
  // Let the browser handle everything naturally
  event.respondWith(fetch(event.request).catch(() => {
    // If fetch fails, return a basic error response instead of crashing
    return new Response('Network error', {
      status: 408,
      statusText: 'Request Timeout'
    })
  }))
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

  event.waitUntil(
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


