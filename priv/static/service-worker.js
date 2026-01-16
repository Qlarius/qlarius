self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url)
  
  // In development, convert HTTPS localhost requests to HTTP
  if (url.hostname === 'localhost' && url.protocol === 'https:') {
    url.protocol = 'http:'
    const newRequest = new Request(url.toString(), {
      method: event.request.method,
      headers: event.request.headers,
      body: event.request.body,
      mode: 'cors',
      credentials: event.request.credentials,
      cache: event.request.cache,
      redirect: event.request.redirect,
      referrer: event.request.referrer,
      integrity: event.request.integrity
    })
    event.respondWith(fetch(newRequest))
  } else if (url.hostname === '10.0.2.2') {
    // Handle Android emulator requests - pass through to avoid opening browser
    event.respondWith(fetch(event.request))
  } else {
    // For all other requests, pass through
    event.respondWith(fetch(event.request))
  }
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


