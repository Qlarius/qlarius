self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))
self.addEventListener("fetch", (event) => {
  // In development, convert HTTPS localhost requests to HTTP
  const url = new URL(event.request.url)
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
  } else {
    event.respondWith(fetch(event.request))
  }
})


