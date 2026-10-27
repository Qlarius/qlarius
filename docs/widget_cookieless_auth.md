# Cookieless widget auth

Implementation notes for the plan in `cookieless_widget_auth` (Oct 2026).
Nothing here is committed, pushed, or deployed; `/live` is untouched.

## The bug, in one paragraph

Publisher widgets are `/widgets/*` LiveViews inside a cross-site iframe.
Browsers that block third-party cookies (Safari, Firefox strict, Brave,
Chrome with 3P cookies off) never send `_qlarius_key` to the iframe.
`Phoenix.Socket.Transport.connect_session/4` then yields a `nil` session,
`Phoenix.LiveView.Channel` answers the join with `{:error, %{reason: "stale"}}`,
and the LiveView JS treats `stale` as "reload the page now" — with no delay
and no counter (the `MAX_RELOADS` jitter path only covers socket close code
1000). The iframe reloaded 6–7×/s and tripped Cloudflare's 429.

## What changed

### Server

| File | Change |
| --- | --- |
| `lib/qlarius_web/auth/widget_token.ex` (new) | `Phoenix.Token`s with their own salt. `:anon` (1 day, sync id only), `:authed` (120 s, single-use jti via ETS, user session token), `:session` (1 day, multi-use, user session token — see Variance 1). `session_for/1` builds the same map the cookie would hold plus a `"widget_token_session" => true` marker. |
| `lib/qlarius_web/widget_socket.ex` (new) | `use Phoenix.Socket` with the two LiveView channels. `connect/3` resolves the session as cookie → `widget_token` param → `%{}` and hands it to `Phoenix.LiveView.Socket.connect/3`. Never `nil`. |
| `lib/qlarius_web/endpoint.ex` | `socket "/widgets/live"` now uses `QlariusWeb.WidgetSocket`. `check_origin: false` and Phoenix's CSRF check are unchanged. |
| `lib/qlarius_web/live/widget_session_hooks.ex` (new) | `on_mount` in the `/widgets` live_session. For a token-backed authed mount it pushes `qadabra:widget-session-token` with a `:session` token. `clear_widget_session/1` deletes the DB session token and broadcasts `:anonymous` so a cookieless widget can log out. |
| `lib/qlarius_web/router.ex` | `WidgetSessionHooks` added to the `/widgets` live_session. `EnsureSessionSyncId` in `:widgets` takes `accept_query: true`. New `:auth_exchange` pipeline (json, fetch_session, EnsureSessionSyncId, secure headers — no CSRF) hosts `POST /auth/extension_exchange` and `POST /auth/finalize_session` on both the default and the `qlinkin.bio` host scopes. `extension_token` / `invalidate_extension_token` stay on `:auth_finalize` with CSRF. |
| `lib/qlarius_web/controllers/auth/finalize_session_controller.ex` | Same treatment as the exchange: accepts `sync_id`, returns `200 {"widget_token": <authed>}`. Without this the in-iframe AuthSheet's OTP finalize got a 403 from `protect_from_forgery` in cookieless browsers ("Something went wrong finishing sign-in"). The single-use 60 s finalize token and the per-IP rate limit are the gate. |
| `lib/qlarius_web/plugs/ensure_session_sync_id.ex` | Optional UUID `sync_id` query param seeds the id when the session has none (widget routes only). Resolved id also assigned to `conn.assigns.session_sync_id`. |
| `lib/qlarius_web/layouts/root.html.heex` | Embed documents get `<meta name="widget-socket" content="/widgets/live">` and `<meta name="widget-token" content={anon token}>`. |
| `lib/qlarius_web/controllers/auth/extension_exchange_controller.ex` | Accepts `sync_id` (UUID only), puts it in the session before `log_in_user_from_finalize/3` (which preserves it across `renew_session`), and returns `200 {"widget_token": <authed>}` instead of `204`. |
| `lib/qlarius_web/controllers/auth/popup_done_controller.ex` | Accepts `opener_origin` + `sync_id`. If the origin passes `Endpoint.check_ws_origin/1` (https only; http allowed for localhost / 127.0.0.1 / 10.0.2.2; no path/query/fragment) and the popup session has a user, the message to `window.opener` carries a `widget_token` and is posted to that origin only. Otherwise the legacy `{type}` message to `*`. The page also recovers opener details stashed in `sessionStorage` for the magic-link path and re-requests itself with them. `Cache-Control: no-store`. |
| `lib/qlarius_web/live/widgets/ads_ext_live.ex` | `confirm_widget_logout` calls `WidgetSessionHooks.clear_widget_session/1` and tells the client whether it was a token session. |
| `lib/qlarius_web/live/widgets/wallet_live.ex` | Crashed on `current_scope.user` with nil scope; now renders a connect prompt. |
| `lib/qlarius_web/live/widgets/arcade/arcade_live.ex` | Gift welcome card read `@current_scope.wallet_balance`; gated on a non-nil scope. |

### Client

| File | Change |
| --- | --- |
| `assets/js/widget_socket.js` (new) | Token holder (`widgetToken()`, `setUpgradeToken`, `setSessionToken`, `clearAuthedTokens`); `installReloadGuard` wraps `liveSocket.redirect` for same-document redirects and `window.location.reload` with a sessionStorage cap of 2 reloads per 10 s; `reconnectWidgetSocket` (no timed reload fallback); `listenForSessionTokens`; `listenForParentExtensionHint` (accepts `sponster_extension_present` only from `new URL(host_url).origin` and only from `window.parent`); `requestStorageAccess`. |
| `assets/js/app.js` | LiveSocket path comes from the `widget-socket` meta (`/live` elsewhere); `widget_token` added to params on widget documents; `reconnectLiveSocket` skips the 5 s reload in widgets; reload guard, session-token listener and parent hint wired before `connect()`; `AuthPopup` appends `opener_origin` + `sync_id` on widget documents, fires `requestStorageAccess()` inside the click, and stores a returned `widget_token` before reconnecting; `ConnectPage` stashes `opener_origin`/`sync_id` in `sessionStorage`; `AuthFinalize` sends `sync_id` in widgets, treats 200 or 204 as success, stores a returned `widget_token` before reconnecting, reports a 403 as `forbidden`, and navigates to `popupDoneUrl()` in popups; `SponsterWidgetBridge.sessionLogout` drops tokens and skips the CSRF `/logout` fetch for token sessions. |
| `assets/js/hooks/extension_bridge.js` | Exchange sends `sync_id` in widgets, handles `200 {widget_token}` (and still `204`), and reconnects; `please-reconnect` carries `widget_token` and `reason === "extension_logout"` clears tokens; widget reconnects have no reload fallback; `syncExtensionWithSessionDebounced({reset: true})`. |
| `browser_extensions/qadabra_chrome_xtension/content.js` | `exchangeVault` no longer sends a CSRF header, passes `sync_id` on widget documents, returns `{ok, widgetToken}`; `askPageReconnect` forwards `widget_token`. `background.js` already accepted `res.ok`; unchanged. |
| `priv/static/sponster-tipjar-widget-ext-script.js`, `tiqit-arqade-widget-script.js`, `tiqit-pass-widget-script.js` | Mint one UUID per host page (`window.__qadabraSyncId`, `crypto.randomUUID` with a fallback) and pass `sync_id` + `host_url` to every widget iframe URL. |

### Tests (new)

- `test/qlarius_web/auth/widget_token_test.exs`
- `test/qlarius_web/widget_socket_test.exs` — includes a real `Phoenix.LiveView.Channel` join with `connect_info: %{session: nil}`: `WidgetSocket` joins; `Phoenix.LiveView.Socket` replies `stale` (the regression).
- `test/qlarius_web/plugs/ensure_session_sync_id_test.exs`
- `test/qlarius_web/controllers/auth/extension_exchange_controller_test.exs`
- `test/qlarius_web/controllers/auth/finalize_session_controller_test.exs` — cookieless finalize succeeds with a `widget_token`; replayed, expired, invalid, and missing tokens are denied.
- `test/qlarius_web/controllers/auth/popup_done_controller_test.exs`
- `test/qlarius_web/live/widgets/cookieless_mount_test.exs` — all nine `/widgets/*` LiveView routes mount with `current_scope: nil`; token-backed authed mount pushes a session token; cookie-backed mount does not; token-backed logout deletes the DB session token.
- `test/support/fixtures/widget_auth_fixtures.ex` — see "Files touched outside expected dirs".

## Decisions log

1. **Keep CSRF on `/widgets/live`.** Phoenix requires `check_origin` or `check_csrf`; origins are unknown, so CSRF stays. The fix is a non-nil session, not a disabled check. The cookie path is still gated by CSRF; the token path is gated by the token's signature and age.
2. **Cookie wins over token.** When the browser does send the cookie, the token is ignored. This keeps cookie-capable browsers on the exact previous behaviour and means Storage Access, once granted, quietly takes over.
3. **Anon token on every embed render.** Costs one HMAC per widget page; gives sibling iframes a shared `session_sync_id` even with no cookie.
4. **`sync_id` from the loader, validated as UUID, lowercased.** Only honoured when the session has no id, and only on the `:widgets` pipeline and the exchange endpoint. It is an unauthenticated grouping hint, so it must never carry authority; it only selects a PubSub topic name.
5. **Exchange moved off CSRF.** The vault token is device-bound, 7-day, revocable, and per-IP rate limited, and the controller already treats it as the credential. A cookieless iframe cannot hold a CSRF token tied to a session it never receives. The two other extension routes still require CSRF because they act on the cookie session.
6. **`200 {widget_token}` instead of `204`.** Clients that only check `res.ok` keep working (`background.js` does). `content.js` and `extension_bridge.js` now read the body.
7. **popup_done validates `opener_origin` against `Endpoint.check_ws_origin/1`.** A widget iframe's origin is one of ours (apex, subdomain, gigalixir, localhost), the same set the socket already trusts. The token is posted with that origin as `targetOrigin`; no origin, no token.
8. **Opener details travel through the popup's `sessionStorage`**, not the `/connect` LiveView. `ConnectLive`, `LoginLive`, `RegistrationLive`, `AutoLoginController` are unchanged. `popup_done` with no query param checks the stash and re-requests itself, covering the magic-link redirect in `AutoLoginController`.
9. **Reload cap wraps `liveSocket.redirect` for same-document targets.** That is the exact call `view.onJoinError` makes for `stale`/`unauthorized`, and where `reloadWithJitter` ends. Redirects to a different URL (real navigation) pass untouched. `window.location.reload` is also wrapped where the engine allows it.
10. **Extension probe stays parallel, not serial.** `liveSocket.connect()` and `startExtensionAuthBridge()` were already back-to-back at load; the anon mount shows immediately and the exchange upgrades in place. Blocking the first paint on an 800 ms probe was rejected.
11. **Storage Access is fired, not awaited, inside the Connect click.** `window.open` must stay synchronous with the gesture; `requestStorageAccess()` is a non-consuming activation check, so firing it first and opening the popup immediately works in both Chromium and WebKit. Result is informational — a grant means the next reconnect carries the cookie and Decision 2 takes over.
12. **Logout from a cookieless widget happens server-side in the LiveView.** `POST /logout` cannot pass CSRF without a cookie. `WidgetSessionHooks.clear_widget_session/1` deletes the DB session token (invalidating every widget token that carries it) and broadcasts `:anonymous`; the client drops its tokens and reconnects.

## Variances from the plan (review these)

1. **A third token kind, `:session`.** The plan had `anon` + single-use `authed`. A single-use hand-off alone breaks on the first reconnect after upgrade (network blip, WS→longpoll fallback): the used jti falls back to `%{}` and the user silently becomes anonymous. So after a token-backed authed mount the LiveView pushes a `:session` token (1 day, multi-use) that the client uses for reconnects. Its authority is the DB session token inside it — the same thing the cookie holds — and logout deletes that row. The `:authed` hand-off stays single-use and 120 s.
2. **`"widget_token_session" => true` marker in the session map.** Needed so `WidgetSessionHooks` and `AdsExtLive` can tell a token session from a cookie session. It is a plain session key with no authority.
3. **`WalletLive` and `ArcadeLive` gift card fixes** were outside the plan's listed files but required by the "every `/widgets/*` mounts with nil scope" item.
4. **`reconnectWidgetSocket` detaches its `onOpen` handler** after firing, where the old code left handlers accumulating on every reconnect.
5. **`host_url` added to the Tiqit loaders.** It was only on the tipjar loader; the parent-origin check for `sponster_extension_present` needs it everywhere.

## Security judgments

- **Token in a URL query string.** `widget_token` rides the websocket/longpoll URL like `_csrf_token` already does. Anon tokens carry nothing sensitive. Authed/session tokens carry the user session token, as the cookie does; they are signed, and the authed one is single-use and 2 minutes. Logs: Phoenix does not log socket query strings by default; Cloudflare access logs would see them — same exposure class as the existing `/auth/*` POST bodies over TLS, but worth a note.
- **Replay of a `:session` token.** Multi-use for a day. Equivalent to stealing the cookie; mitigated the same way (TLS, logout deletes the row, 10-day DB token expiry in `get_user_by_session_token`).
- **`popup_done` postMessage target.** Previously `*` with no payload. Now `*` with no payload, or a validated own-origin with a token. The widget's `AuthPopup` listener additionally host-allowlists `event.origin` before using the token.
- **Sync id as an attack surface.** An attacker controlling a publisher page can choose the UUID and so put the visitor's widgets on a topic of their choosing. The topic only carries `{:session_auth_changed, state}`; a receiver reacts by reconnecting with whatever credentials it already has. Worst case is a spurious reconnect. Can't be used to join another session.
- **Exchange without CSRF.** Already discussed in Decision 5. Rate limit and `AuditLog` events unchanged. The `sync_id` it writes into the session is a UUID-validated topic name.
- **`check_origin: false` on `/widgets/live` remains**, as before.

## Things deliberately left alone

- `/live` socket, `HostAwareSession`, `SessionSyncHooks`, `UserAuth`, `ConnectLive`, `AuthSheet` component, `LoginLive`, `RegistrationLive`, `AutoLoginController`.
- `background.js` — its exchange already accepted `res.ok`; its first-party cookie jar flow is unaffected.
- The `tabular-amount` class in `arcade_live.ex`'s gift card (pre-existing).
- `test/support/fixtures/accounts_fixtures.ex` — `user_fixture/0` is broken (calls removed `Accounts.register_user/1`); not repaired, see below.
- Sibling upgrade in cookieless browsers: when the Connect popup signs in from one widget, only that widget receives the hand-off token. Siblings on the same `sync_id` get the `:authed` broadcast, reconnect, and stay anonymous unless the extension is present or Storage Access was granted. Fixing this needs either a multi-use hand-off or a `BroadcastChannel` relay; left for follow-up.
- Echoing a cookieless popup sign-in into the extension happens from the popup window (`AuthFinalize` runs `mintTokenIntoExtension` there, first-party), not from the widget.
- Widget vault exchange after `extension_logout` in cookieless mode: the client drops its tokens; the DB session token created by that exchange is not deleted until it expires or the user logs out elsewhere.

## Files touched outside the expected directories

- `test/support/fixtures/widget_auth_fixtures.ex` (new). `Qlarius.AccountsFixtures.user_fixture/0` no longer works (`Accounts.register_user/1` was removed), so a small fixture registers a user the way `connect_auth_sheet_test` does (seed traits + `Accounts.register_new_user/1`).
- `lib/qlarius_web/live/widgets/wallet_live.ex`, `lib/qlarius_web/live/widgets/arcade/arcade_live.ex` — nil-scope fixes (Variance 3).
- `priv/static/tiqit-*.js` — `host_url` (Variance 5).

## What could not be verified locally, and how to verify in prod

The dev server in the IDE terminal was started before this change. Phoenix builds the socket dispatch and starts each socket's `Phoenix.Socket.PoolSupervisor` at endpoint boot, so after the code reloader picked up the new `Endpoint`, `/widgets/live` resolved to `QlariusWeb.WidgetSocket` whose pool was never started: the upgrade returned 500 and the client saw close code 1011. `/live` kept working, which confirms the cause. The running server was not restarted (it is the user's terminal). A fresh boot — any deploy, or `mix phx.server` restarted locally — starts the pool.

Verified locally without a restart:

- Widget pages render the two meta tags and the LiveSocket endpoint is `wss://…/widgets/live/websocket?_csrf_token=…&widget_token=…`.
- `installReloadGuard` is installed (`liveSocket.__qadabraReloadGuard === true`).
- With the socket failing (the 500 above), the iframe did **not** reload-loop: `sessionStorage["qadabra:widget-reloads"]` stayed null and the URL stayed put.
- The exact server path is covered by `widget_socket_test.exs`: a real `Phoenix.LiveView.Channel` join with `session: nil` succeeds through `WidgetSocket` and replies `stale` through the stock socket.

Prod verification steps (after restart/deploy):

1. Safari (default ITP) on a publisher page with the tipjar widget: the widget shows the promo announcer within a second, no reload loop, no 429s in Cloudflare analytics for `/widgets/*`.
2. DevTools in the iframe: `document.querySelector('meta[name=widget-token]')` present; WS URL is `/widgets/live/...&widget_token=...`; `[data-phx-main]` has class `phx-connected`.
3. Extension installed and signed in: the widget upgrades to authed within ~1–2 s without a page reload (network tab shows `POST /auth/extension_exchange` → `200 {widget_token}` then a socket reconnect).
4. No extension: click Connect → popup → sign in → popup closes → widget shows authed state in place. Network shows `GET /auth/popup_done?opener_origin=…` and a socket reconnect; `phx:qadabra:widget-session-token` fires once.
5. Reconnect resilience: toggle the network off/on; the authed widget stays authed (session token).
6. Logout from the widget drawer: the widget returns to promo; `user_tokens` row for that session is gone.
7. Reload cap: temporarily break the token (e.g. edit the meta content in DevTools and `liveSocket.disconnect(); liveSocket.connect()`): at most two reloads within 10 s, then `document.documentElement.dataset.widgetReloadCapped === "true"` and the page stays.
8. Chrome with third-party cookies allowed: behaviour identical to before (cookie wins).

## Test commands and results

```
MIX_ENV=test mix test \
  test/qlarius_web/auth/widget_token_test.exs \
  test/qlarius_web/widget_socket_test.exs \
  test/qlarius_web/plugs/ensure_session_sync_id_test.exs \
  test/qlarius_web/controllers/auth \
  test/qlarius_web/live/widgets/cookieless_mount_test.exs \
  test/qlarius_web/auth/extension_identity_token_test.exs \
  test/qlarius_web/live/connect_auth_sheet_test.exs
```

Result: `52 tests, 0 failures` (the `conn_case.ex` / `accounts_fixtures.ex` compile warnings are pre-existing).

```
mix compile --force --warnings-as-errors   # clean
mix esbuild qlarius                        # bundles; output dir is untracked
```

Formatted with `mix format` on touched `.ex`/`.exs`/`.heex` files only. JS files follow the surrounding style (no project formatter configured for them).
