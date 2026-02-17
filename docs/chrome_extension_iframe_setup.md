# Chrome Extension Iframe Setup

Qlarius is embedded in a Chrome extension popup via an iframe. This document
explains the configuration required for this to work and the failure modes
that occur when it breaks.

## Architecture

```
Chrome Extension Popup (chrome-extension://...)
  └── <iframe src="https://qlarius.gigalixirapp.com/home?extension=true&popup=true&context=chrome_extension">
        └── Full Phoenix LiveView app
```

The extension popup (`popup.html`) loads the production app in an iframe.
LiveView runs inside the iframe — the extension itself has no app logic.

## Critical Configuration: Session Cookie `SameSite`

**This is the #1 thing that breaks.** The session cookie must use
`SameSite=None; Secure=true` in production for the extension to work.

### Why

LiveView has a two-phase mount:

1. **HTTP GET** — Browser loads the iframe. Chrome sends the session cookie
   because it treats this as a navigation.
2. **WebSocket upgrade** — LiveView JS opens a WebSocket. This is NOT a
   navigation. With `SameSite=Lax`, Chrome withholds the session cookie
   because the top-level site (`chrome-extension://...`) differs from the
   iframe site (`qlarius.gigalixirapp.com`).

Without the cookie on the WebSocket upgrade, the server sees a "stale"
session and tells the client to reload. The reload starts the cycle over →
**infinite reload loop**.

### Configuration

In `config/prod.exs`:

```elixir
session_options: [
  store: :cookie,
  key: "_qlarius_key",
  signing_salt: "Tvun6ICt",
  same_site: "None",   # MUST be "None" for extension iframe
  secure: true,         # Required when SameSite=None
  http_only: true,
  max_age: 60 * 60 * 24 * 365
]
```

In `config/dev.exs`:

```elixir
session_options: [
  store: :cookie,
  key: "_qlarius_key",
  signing_salt: "Tvun6ICt",
  same_site: "None",   # Same as prod — keeps parity
  secure: true
]
```

**If `same_site` is changed to `"Lax"` in prod, the extension will break
with an infinite reload loop.** The console error will show:

```
error: unauthorized live_redirect. Falling back to page request - {reason: 'stale'}
```

### Security Note

`SameSite=None` is safe here because:
- `Secure=true` ensures the cookie is only sent over HTTPS
- `http_only: true` prevents JavaScript access
- Phoenix has its own CSRF token protection on all forms/actions

## Other Required Configuration

### Endpoint (`lib/qlarius_web/endpoint.ex`)

The `check_origin` function must allow WebSocket connections from the
extension and the production domain:

```elixir
check_origin: fn
  %URI{host: host} when is_binary(host) ->
    allowed_hosts = [
      "localhost",
      "qlarius.gigalixirapp.com"
    ]
    Enum.any?(allowed_hosts, &(host == &1 || String.ends_with?(host, "." <> &1)))

  %URI{scheme: "chrome-extension"} -> true
  _other -> false
end
```

### CSP Frame Ancestors (`lib/qlarius_web/router.ex`)

The `allow_iframe` plug must include `chrome-extension:` in `frame-ancestors`:

```
frame-ancestors * chrome-extension:;
```

### Extension Manifest (`manifest.json`)

The extension needs appropriate permissions and CSP for connecting to the
production domain and establishing WebSocket connections.

### App JS (`assets/js/app.js`)

In extension context (`?extension=true`):
- Service worker registration is skipped (do NOT unregister existing ones)
- Topbar progress bar is disabled
- LiveSocket passes `extension: 'true'` as a param for server-side detection

## Debugging

If the extension shows a reload loop:

1. Open the extension popup, right-click → Inspect
2. Check the console for the error message
3. Common errors:
   - `unauthorized live_redirect ... {reason: 'stale'}` → Session cookie issue (check `SameSite`)
   - `WebSocket connection failed` → Check `check_origin` in endpoint
   - `Refused to frame` → Check CSP `frame-ancestors`

Enable LiveSocket debug in extension context (already enabled in app.js)
to see detailed LiveView connection logs.

## Files Involved

| File | What it does |
|------|-------------|
| `config/prod.exs` | Session cookie settings (SameSite) |
| `config/dev.exs` | Session cookie settings (must match prod) |
| `lib/qlarius_web/endpoint.ex` | WebSocket check_origin, connect_info |
| `lib/qlarius_web/router.ex` | CSP headers, frame-ancestors |
| `assets/js/app.js` | Extension detection, SW handling, debug logging |
| `browser_extensions/qadabra_chrome_xtension/popup.html` | Iframe URL |
| `browser_extensions/qadabra_chrome_xtension/popup.js` | PostMessage listener |
| `browser_extensions/qadabra_chrome_xtension/manifest.json` | Extension permissions/CSP |
