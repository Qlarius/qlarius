// Extension popup - receives postMessage from iframe (app) only from allowed origins.
// LiveView runs inside the iframe; the popup cannot access iframe content (cross-origin).

const ALLOWED_ORIGINS = [
  "https://localhost:4001",
  "http://localhost:4000",
  "https://qlarius.gigalixirapp.com"
];

function isAllowedOrigin(origin) {
  return origin && ALLOWED_ORIGINS.some(allowed => origin === allowed);
}

window.addEventListener("message", (event) => {
  if (!isAllowedOrigin(event.origin)) return;

  if (event.data?.status === "liveview-mounted") {
    console.log("✅ LiveView mounted in iframe");
  } else if (event.data?.status === "liveview-not-mounted") {
    console.warn("⚠️ LiveView not mounted in iframe");
  }
});