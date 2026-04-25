# Qlink / Cross-Domain Auth Refactor Plan

Status: **Planning — approved decisions baked in**
Owner: Trae
Last updated: 2026-04-24 (rev 2: split components, in-place auth, session-based resume)

---

## 1. Goal

Unify authentication and registration across all Qadabra-family domains (`qadabra.app`, `qlink.qadabra.app`, `www.qadabra.app`, `qlinkin.bio`) and third-party publisher embeds around in-place SMS-code auth driven by a pair of LiveComponents (`AuthSheet` for public auth, `ProxyUserSheet` for admin proxy-user creation). Eliminate cross-domain redirects, eliminate page reloads on native surfaces, provide safe link-out fallbacks for iframe contexts, and design extension-driven identity propagation in from day one.

The target UX: an unauthed user on a qlink page scrolled to a tip jar clicks to tip, completes auth in a modal, and the modal closes to reveal the page **in the same scroll position** with the wallet strip now showing balance — no page reload, no scroll jump.

## 2. Guiding principles

1. **Phone is the universal identity.** No passwords, no email magic links, no OAuth in this architecture. One identifier, one SMS flow, one user record across every domain.
2. **In-place auth on native surfaces.** Authentication completes without a page navigation: server sets the session cookie via a fetch-driven finalize endpoint; LiveView socket reconnects with the new session; DOM patches in place. Scroll position is preserved by the browser (no navigation happens).
3. **Two focused components, shared sub-components.** `AuthSheet` handles public auth (phone → code → maybe signup). `ProxyUserSheet` handles admin proxy-user creation. Both embed the same extracted alias/data/confirm step components.
4. **Native inline, iframe link-out.** Native pages (qlink pages, marketer pages, admin settings) run the modal in-place. Iframed widgets show a short interstitial that opens Qadabra in a new tab for sign-in or sign-up.
5. **Referral is a context, not a field.** The surface that opens the modal supplies the referral source — from the creator, campaign, URL `?ref=`, or (for proxy) the admin.
6. **Keep the schema strict.** Option A: full user data collected at signup (phone, alias, sex, birthdate, zip). No partial users, no profile-completion gate. No DB changes.
7. **Design the extension bridge in from day one.** The modal emits a captureable identity token on success, even before the extension exists to consume it.
8. **Reuse existing auth primitives.** Twilio verify, `Auth.get_user_by_phone/1`, `Accounts.register_new_user/2`, `HostAwareSession` are unchanged. One new primitive is the finalize endpoint that sets a session cookie from a signed exchange token.
9. **The sheet is a discovery-surface component, not a universal auth modal.** It appears only where an anon user could plausibly land and choose to convert. Authed-operator surfaces (creator dashboards, marketer dashboards, admin panels) continue to use the existing `/login` redirect when accessed unauthed — no change to that boundary. Authed-consumer surfaces (wallet, mefile builder, etc.) may opt into an auto-open sheet as a soft gate replacing the redirect (see §5.10 and Follow-ups).

## 3. Scope

### Surface taxonomy (defines where each piece applies)

| Category | Examples | Default user state | Auth UX |
|---|---|---|---|
| **A. Public / discovery** | qlink pages (qadabra + qlinkin.bio), landing pages, widget standalone routes, Hi/onboarding | Often anon | `AuthSheet` on CTA action |
| **B. Authed consumer** | MeFile builder, wallet, tiqits, referrals, PWA bottom-nav pages | Always authed (today: `/login` redirect if not) | Current: redirect. Optional future: soft-gate auto-opens `AuthSheet` (§5.10, post-B6) |
| **C. Authed operator** | Creator dashboards, marketer campaign manager, admin panels | Always authed | Redirect to `/login` — unchanged |

`ProxyUserSheet` is a narrow-purpose component, appearing only on the admin's proxy-users management page in settings.

### In scope

- `AuthSheet` LiveComponent (public auth: phone → code → auto-transition to signup when needed)
- `ProxyUserSheet` LiveComponent (admin proxy-user creation, no phone step)
- Shared sub-components: `alias_picker`, `data_step`, `confirm_step`
- In-place auth completion: `POST /auth/finalize_session` controller + exchange token + JS reconnect hook
- Iframe detection + link-out interstitial
- Referral context protocol
- `qlinkin.bio` promotion to fully authed transactional surface (flip live_session, add full `:browser` pipeline, Cloudflare cache-bypass rule)
- Wiring the components into qlink page, marketer surfaces, admin proxy list
- Retiring `/register?mode=proxy` UI (admin UI only, via modal)
- Extension exchange emission path + server endpoint (behind feature flag until extension ships)
- Rate limits, captcha hook, testing matrix

### Out of scope (deferred)

- Safari / Firefox browser extensions (Chrome first; follow-up)
- Extension runtime itself (design the handshake; ship in a later batch)
- Phone-loss account recovery flow (support-driven for now)
- International phone support (US-only today, unchanged)
- Internationalization / localization of modal copy
- Turning `/login` and `/register` themselves into modal-backed pages (left as future cleanup)

## 4. Decisions (locked)

| # | Question | Decision |
|---|---|---|
| Q1 | Referral when no inherent context | **(a)** Allow signup without referral. No referral field shown on modal path. |
| Q2 | Iframe modal sign-in behavior | **(a)** Both sign-in and sign-up link out when iframed. |
| Q3 | `qlinkin.bio` authed vs anon | **(a)** Fully authed transactional surface. Flip live_session, Cloudflare cache-bypass. |
| Q4 | `/register?mode=proxy` UI | **(a)** Retire. Admin-only via modal from settings. |
| Q5 | `/login` and `/register` full pages | **(b)** Keep both as fallbacks. May later rewrite to render `AuthSheet` internally. |
| Q6 | Iframe detection | **(c)** Hybrid: route heuristic sets initial assumption; JS hook confirms / corrects. |
| Q7 | Extension token emission | **(a)** Emit captureable token from day one, behind feature flag. |
| Q8 | Feature-flag granularity | **(b)** Per-surface flags for gradual rollout. |
| Q9 | Auth completion UX | **In-place via socket reconnect.** No page reload. Scroll preserved by doing no navigation. |

## 5. Architecture

### 5.1 Component split

**Two LiveComponents, each focused, sharing extracted step sub-components.**

#### `AuthSheet` — public auth

- Path: `lib/qlarius_web/components/auth_sheet.ex` (+ `/auth_sheet/*.html.heex`)
- Flows: **sign-in** or **sign-up** (resolved server-side at phone-verify time; not a parent concern)
- Parent-facing API (no `mode`, no `return_to`):

  ```elixir
  <.live_component
    module={QlariusWeb.Components.AuthSheet}
    id="auth-sheet"
    referral_context={context}      # %ReferralContext{} or nil
    resume={resume_id}              # opaque string or nil, e.g. "tip:jar-1"
    surface_flag={:on_qlink_page}   # for feature flag + telemetry
  />
  ```

- **Internal state machine:**

  ```
  :phone
    → "send_code"
  :code
    → "verify_code"
    → resolves to :sign_in_finalizing  (phone known)
                  OR
                  :carrier_check  (phone new, proceed to signup)
  :carrier_check
    → :alias
  :alias
    → :data
  :data
    → :confirm
  :confirm
    → "complete"
    → :sign_up_finalizing
  :sign_in_finalizing / :sign_up_finalizing
    → (push_event to client → fetch /auth/finalize_session)
    → :reconnecting
  :reconnecting
    → (client disconnects/reconnects socket; LV re-mounts authed → modal no longer rendered)
  ```

- **The user never supplies `mode`**; the component decides `:sign_in` vs `:sign_up` branching internally based on phone verification result.

- **Shared sub-components** (extracted in B1):
  - `<.alias_picker>` — from `RegistrationLive.step_two/1`
  - `<.data_step>` — from `RegistrationLive.step_three/1` (sex / birthdate / zip)
  - `<.confirm_step>` — from `RegistrationLive.step_four/1`
  - `<.otp_input>` — already exists in `QlariusWeb.Components.CustomComponentsMobile`
  - `<.date_input>` — already exists there

#### `ProxyUserSheet` — admin proxy-user creation

- Path: `lib/qlarius_web/components/proxy_user_sheet.ex` (+ templates)
- Flow: **create proxy user** (no phone, no code, no reconnect)
- Parent-facing API:

  ```elixir
  <.live_component
    module={QlariusWeb.Components.ProxyUserSheet}
    id="proxy-sheet"
    admin={@current_scope.user}
  />
  ```

- **Internal state machine:**

  ```
  :alias → :data → :confirm → "complete"
    → register_new_user with admin's referral code and true_user_id
    → send_update back to parent + PubSub broadcast
    → sheet closes
  ```

- Uses the **same** `<.alias_picker>` / `<.data_step>` / `<.confirm_step>` sub-components.
- Never redirects. Never calls finalize. Admin remains signed in throughout.
- On success, parent LV receives the new user via `send_update/2` and refreshes its proxy-users list without a reload.

### 5.2 Iframe detection path (both components)

1. On mount, component renders its first screen based on **route heuristic**:
   - LV under `:widgets` live_session → assume iframed
   - LV anywhere else → assume native
2. A `phx-hook` (`IframeDetect`) on the sheet root `<div>` pushes `iframe-status` with `window.self !== window.top` on first connected render.
3. If the JS-confirmed status differs from the heuristic, the component swaps to/from the link-out interstitial.
4. **Link-out interstitial** (iframed case): short copy + primary button `[Open Qadabra to sign up ↗]` / `[Sign in ↗]` opening `https://qadabra.app/register` / `https://qadabra.app/login` via `target="_blank"`. No in-iframe auth flow attempted.

### 5.3 In-place auth completion (§5.9 details; summary here)

After code verification (sign-in) or user creation (sign-up), the sheet:
1. Obtains a signed single-use exchange token from the server (via `push_event`).
2. JS hook does `fetch("/auth/finalize_session", POST, {token})`.
3. Controller validates the token, sets the session cookie, returns 204.
4. Sheet pushes `auth:reconnect-now` → JS calls `liveSocket.disconnect(); liveSocket.connect()`.
5. LV re-mounts with authed scope. DOM patches in place. Modal is no longer rendered (its render condition checks `@current_scope.user`). Scroll preserved by design (no navigation).
6. Resume intent (stashed in session by step 3) auto-fires on post-reconnect mount.
7. 5-second reconnect timeout fallback: if reconnect fails, `window.location.reload()` to ensure the user lands authed.

### 5.4 Referral context protocol

```elixir
defmodule Qlarius.Referrals.Context do
  defstruct [:source, :code, :source_id]
  # source :: :creator | :marketer | :url | :proxy | nil
end
```

Constructors:
- `Context.from_creator(%User{})` — resolves creator's referral code, generating one if absent (same logic as current proxy path)
- `Context.from_marketer(%Marketer{})`
- `Context.from_url(code_string)` — for `?ref=CODE`
- `Context.from_admin(%User{})` — for `ProxyUserSheet`

Surfaces pass the context when opening the sheet; the component feeds `context.code` into `Accounts.register_new_user(attrs, code)` on completion. If `context` is `nil`, registration proceeds without a referral code (per Q1).

No visible referral UI in the modal. The `/register` full-page route continues to show the step-0 referral field for direct-visit signups.

### 5.5 Feature flags (per-surface)

Config keys in `config/runtime.exs`:

```elixir
config :qlarius, :auth_sheet,
  on_qlink_page: true,            # qlink pages on qadabra-family
  on_qlinkin_bio: false,          # qlinkin.bio (after B6)
  on_landing_pages: false,        # qadabra.app/ and marketing surfaces (future)
  on_widget_standalone: false,    # /widgets/* when opened top-level (rare; defaults to link-out)
  on_authed_consumer: false,      # Category B soft-gate (§5.10; post-launch)
  on_admin_proxy: false,          # ProxyUserSheet flag (distinct from AuthSheet)
  extension_token_emit: false,
  extension_exchange_enabled: false
```

Read via `Application.get_env(:qlarius, :auth_sheet)[:on_qlink_page]`. Each surface wraps its sheet-opening logic in the flag; when false, surfaces fall back to the current `~p"/login"` link behavior.

Authed-operator surfaces (Category C) have no flag — they always use the existing `/login` redirect.

### 5.6 Extension identity bridge (design, not full implementation)

**Token emission (ship in B2):**

After successful finalize (and after the socket reconnect completes), the re-mounted LV `push_event`s `qadabra:auth:emit-token` with a short-lived signed token. JS glue listens and posts it to the Chrome extension's content script via `window.postMessage({ type: "qadabra:identity", token }, "*")`. Extension stores in `chrome.storage.local`.

Token format (signed by server via `Phoenix.Token` with key in `Qlarius.Vault`):

```
{
  user_id: integer,
  device_id: opaque string,
  issued_at: unix_ts,
  expires_at: unix_ts + 7d,
  surface: string  // emitting domain for audit
}
```

**Token exchange (ship in B8):**

Endpoint `POST /auth/extension_exchange` accepts a token, validates signature + expiry, checks device binding, issues a session cookie scoped to the requesting domain (via `HostAwareSession`). Rate-limited. Audit-logged.

**Extension behavior (Phase 2, separate ticket):**

On page load of allowlisted hosts:
1. Check for existing session cookie via a probe endpoint
2. If absent and extension holds a valid token → call `/auth/extension_exchange`
3. On success, page reloads or LV re-mounts with authed scope

**Revocation:**
- Explicit logout on any domain calls `POST /auth/invalidate_token`
- Token rotation every 24h; stale tokens get renewed or rejected

**Security requirements:**
- Token bound to `device_id` captured at emission (opaque random string per extension install)
- Exchange endpoint origin-gated: allowlisted domains only
- Extension content script only injects into allowlisted URLs
- Server audit log for every exchange (user_id, origin, IP, UA)
- Kill switch: `extension_exchange_enabled` config flag

### 5.7 Session & cookie model (no changes)

- `.qadabra.app` shared cookie across all qadabra-family subdomains (Batch 5, already shipped)
- Host-only cookie on `qlinkin.bio` (already handled by `HostAwareSession`)
- Independent sessions per registrable domain; same user records
- Extension token bridges the two registrable domains when installed

### 5.8 Intent resume via session (RETRACTED — see rev 11)

> **Retracted in rev 11.** Kept below for historical context only; do not implement.
>
> Original premise: pre-AuthSheet, sign-in meant a full navigation away from the page, so preserving *what the user was trying to do* across that navigation was a hard requirement. With the in-place AuthSheet shipped (B2/B3) the page never unloads — `liveSocket.disconnect/connect` re-mounts the same LV with an authed session, scroll position intact, every widget still visible. The user's last intercepted action is one tap away. "Re-click the thing" turned out to be acceptable UX at review and eliminates an entire class of stale-session bugs the approach below would have introduced.
>
> If per-action resume ever becomes a real user complaint, it should come in organically as a specific response to that feedback — not be pre-designed here.

Because the in-place auth flow has no URL navigation, resume intent is **stashed in the Plug.Session by the finalize controller**, not passed via URL query params:

1. Sheet opens with `resume: "tip:jar-1"` assign from parent.
2. Sheet emits the resume string alongside the exchange token when calling finalize.
3. `FinalizeSessionController` writes `{:qadabra_resume, "tip:jar-1"}` to the session before returning 204.
4. Post-reconnect LV mount reads from session, dispatches to resume handler, clears the session key.

Resume vocabulary (to be filled by B7):
- `"tip:<jar_id>"` — open tip modal on that jar
- `"buy_tiqit:<class_id>"` — open tiqit purchase on that class
- `"ad_engage:<campaign_id>"` — open sponster engage confirmation
- Others added as surfaces gain modal triggers

Signing note: the resume string is only ever stored server-side after the signed exchange token has been verified, so it doesn't need separate signing.

### 5.9 In-place auth completion — detailed

**Goal:** modal closes to reveal the page beneath in the same scroll position, with wallet strip showing real balance and every previously-intercepted action now functional on re-click. No page navigation, no auto-dispatch — the user resumes their own intent by re-clicking where they left off (see §5.8 retraction note).

**Exchange token:**
- Signed via `Phoenix.Token.sign/3` with key from `Qlarius.Vault`
- Contents: `{user_id, resume, jti, issued_at}`
- TTL: 60 seconds
- Single-use: `jti` stored in ETS (`:qadabra_finalize_jti`) on first redemption; subsequent uses rejected
- Rotation: not needed at token level; TTL is enough

**Endpoint `POST /auth/finalize_session`:**
- Accepts JSON: `{"token": "..."}`
- Header: `x-csrf-token` (standard Phoenix CSRF)
- Validates token via `Phoenix.Token.verify/3` (max_age: 60)
- Checks `jti` against ETS; inserts if unseen, rejects if seen
- Calls `UserAuth.log_in_user_from_finalize/2` — new helper that:
  - Runs the same session-setting side effects as `UserAuth.log_in_user/3`
  - Does NOT call `redirect/2`
  - (B7's planned "stash resume in session" side-effect was dropped in rev 11)
- Responds `204 No Content` on success, `422` with error body on invalid token
- Mounted on both host scopes (qadabra-family + qlinkin.bio)

**JS hook `AuthFinalize`:**
- Attached to the sheet root via `phx-hook`
- Listens for `qadabra:finalize-auth` LV event → does fetch → on 204 pushes `auth:reconnect` back to LV
- Listens for `auth:reconnect-now` LV event → `liveSocket.disconnect(); liveSocket.connect()`
- On fetch failure → pushes `auth:finalize_failed` → LV shows retry UI
- Implements a 5-second reconnect timeout: if the socket doesn't re-establish in time, `window.location.reload()` as graceful-degradation fallback

**Sheet state transitions:**
- `:sign_in_finalizing` and `:sign_up_finalizing` render a friendly "Signing you in..." screen with a subtle spinner
- `:reconnecting` renders the same visual (the socket's brief disconnect briefly freezes LV anyway)
- Post-reconnect mount: LV sees `@current_scope.user` populated, conditional render of the sheet resolves to `nil`, sheet disappears via DOM patch. All previously `maybe_intercept_for_unauth`-gated actions now run for real on re-click.

**Nested LVs:**
- The qlink page has nested LVs (arqade widget, potentially others). On socket reconnect, all nested LVs also re-mount. Each renders its authed state directly; brief loading indicators may flash for 100-300ms. Acceptable; measure in B2.

**Security notes:**
- Exchange token never leaves the server-client pair; never logged in cleartext
- CSRF protection via existing Phoenix token on the fetch
- Rate-limit on `/auth/finalize_session` mirrors the send-code limits (Hammer, per-IP)
- The LV session id changes on reconnect (new session cookie); this is expected and desired — old socket cannot spoof authed state

### 5.10 Category B soft-gate (post-launch option)

**Problem today:** authed-consumer surfaces (wallet, mefile builder, tiqits, referrals) use `UserAuth.require_authenticated_user` to redirect unauthed visitors to `/login`. The redirect is a friction point for deep links: user taps a shared `/wallet` link → bounced to `/login` → signs in → bounced back. Two full page navigations for one action.

**Proposed alternative (not in core B1-B8; follow-up):**

- Replace `:require_authenticated_user` with `:soft_require_auth` on Category B LiveViews.
- If unauthed, the LV mounts in a **gated shell state**: renders a minimal page skeleton (header, brand) plus `AuthSheet` auto-opened over dimmed/blocked content. No server data leaked into the skeleton beyond what a logged-out user could see on a public page.
- On successful in-place auth (§5.9), LV re-mounts authed, renders the actual page content. URL never changed.

**Why deferred:**

- Requires careful audit of every Category B LV to ensure no data leak in the gated-shell render.
- Touches `UserAuth` plug/hook architecture — higher-risk change than a UI component.
- Not required for the hero UX (qlink page tip-at-bottom). That's Category A.

**When revisited:** likely after B6 ships and the sheet has been battle-tested on Category A. Batch TBD; single batch, gated per-surface by `:auth_sheet[:on_authed_consumer]` flag.

**Explicitly NOT proposed for Category C.** Creator/marketer/admin dashboards keep the redirect model — they're operator boundaries, not conversion surfaces. An auto-opening modal on a deep-linked admin URL would be wrong tonally.

## 6. Batches

Each batch is individually shippable. Dependencies noted.

### B1 — Shared primitives extraction (low risk, no behavior change)

**Deps**: none

**Scope:**
- Extract `<.alias_picker>`, `<.data_step>`, `<.confirm_step>` from `RegistrationLive` into shared components under `QlariusWeb.Components.AuthSteps`
- Create `Qlarius.Referrals.Context` struct with constructors
- Create `lib/qlarius_web/components/auth_sheet/` and `lib/qlarius_web/components/proxy_user_sheet/` directory scaffolds (empty)

**Files:**
- new: `lib/qlarius_web/components/auth_steps.ex`
- new: `lib/qlarius/referrals/context.ex`
- edit: `lib/qlarius_web/live/accounts/registration_live.ex` (use extracted components)

**Risk:** visual regressions in existing `/register`. Mitigate with screenshot comparison on all 5 registration steps before/after.

**Ship criterion:** `/register` flow visually and functionally identical.

### B2 — `AuthSheet` sign-in only, in-place completion

**Deps**: B1

**Scope:**
- Build `AuthSheet` LiveComponent with phone → code → (sign-in branch only) state machine
- `POST /auth/finalize_session` controller + `UserAuth.log_in_user_from_finalize/2` helper
- `Phoenix.Token.sign/verify` exchange token + ETS-backed `jti` tracking
- JS hook `AuthFinalize` with disconnect/reconnect orchestration + 5s timeout fallback
- JS hook `IframeDetect` (route heuristic + `window.self !== window.top`)
- Link-out interstitial for iframe context
- Finalizing / reconnecting UI screens
- Emit extension identity token on finalize success (gated by `extension_token_emit` flag; exchange endpoint not yet live)
- Wire into `QlinkPage.Show` on qadabra-family domains behind `:auth_sheet[:on_qlink_page]` flag
- Unknown phone at verify → link-out to `qadabra.app/register` in a new tab (no in-modal signup yet)

**Files:**
- new: `lib/qlarius_web/components/auth_sheet.ex`
- new: `lib/qlarius_web/components/auth_sheet/*.html.heex`
- new: `lib/qlarius_web/controllers/auth/finalize_session_controller.ex`
- edit: `lib/qlarius_web/user_auth.ex` (add `log_in_user_from_finalize/2`)
- edit: `lib/qlarius_web/router.ex` (route on both host scopes)
- new: `assets/js/hooks/auth_finalize.js`
- new: `assets/js/hooks/iframe_detect.js`
- edit: `assets/js/app.js` (wire hooks)
- edit: `lib/qlarius_web/live/qlink_page/show.ex` + `.html.heex`
- edit: `config/runtime.exs` (auth_sheet config)

**Risk:**
- Nested LV flicker on reconnect → measure; mitigate with minimal loading states
- `fetch` failure mid-flow → retry UI in sheet + reload fallback
- Sheet interferes with existing unauth CTAs → feature flag off by default; enable on staging first

**Ship criterion:** sign-in works end-to-end on qlink page on qadabra.app with known phones; modal closes in place with wallet strip updated, no page reload, scroll preserved; unknown phones link out.

### B3 — `AuthSheet` sign-up mode (full Option A)

**Deps**: B2

**Scope:**
- Add carrier-check step (reuse existing `Twilio.validate_carrier/1` with all error branches)
- Add alias → data → confirm screens (rendered via shared sub-components)
- Auto-transition from sign-in to sign-up when verified phone has no user
- Wire `ReferralContext.from_creator` in `QlinkPage.Show`
- User creation → same finalize flow (new user auto-logged-in via in-place reconnect)
- Retire the B2 link-out fallback for sign-up on this surface

**Files:**
- edit: `lib/qlarius_web/components/auth_sheet.ex` + templates
- edit: `lib/qlarius_web/live/qlink_page/show.ex`

**Risk:** cram-factor on mobile. Mitigate with bottom-sheet layout on narrow viewports, step-by-step progression (one screen visible at a time).

**Ship criterion:** full signup completes on qlink page on qadabra.app; new user created with all required fields; creator's referral code applied; in-place auth completion works for the newly-created user.

### B4 — `ProxyUserSheet`

**Deps**: B1 (parallel-safe with B2/B3)

**Scope:**
- Build `ProxyUserSheet` LiveComponent: alias → data → confirm
- Wire from `UserSettingsLive` (or dedicated proxy list LV — confirm at batch start)
- Uses admin's referral code (auto-generating if admin lacks one, reusing existing logic)
- `send_update/2` back to parent on success; PubSub broadcast to refresh proxy users list
- Hide `/register?mode=proxy` entry links in admin UI (route stays alive as fallback)
- Add proxy-user-created flash + "Add another" affordance

**Files:**
- new: `lib/qlarius_web/components/proxy_user_sheet.ex`
- new: `lib/qlarius_web/components/proxy_user_sheet/*.html.heex`
- edit: `lib/qlarius_web/live/user_settings_live.ex` (or appropriate parent LV)

**Risk:** admin referral code auto-generation interaction. Mitigate by reusing existing `RegistrationLive.create_user/1` logic intact.

**Ship criterion:** admin creates proxy user entirely in-modal from settings; proxy list updates without page reload; admin stays signed in throughout.

### B5 — Widget surfaces use `AuthSheet` [SHIPPED — see rev 8]

**Deps**: B3.

**Scope (as shipped):**
- `UnauthCTA.wallet_strip_or_connect/1` and `connect_wallet_modal/1` gained an `on_click` attr so callers can opt in to `phx-click="open_auth_sheet"`; the legacy `<.link href={interact_login_url()} target="_top">` stays as the fallback for third-party iframe embeds and the `qlinkin.bio` anon surface (retired in B6)
- `InstaTipComponents.insta_tip_card/1` forwards via `on_auth_click`
- `ArcadeLive` + `ArcadeSingleLive` gained an `open_auth_sheet` event handler. Standalone mounts host their own `AuthSheet` LC; **nested mounts** (inside `QlinkPage.Show` via `live_render/3`) forward via `send(socket.parent_pid, :open_auth_sheet)` so the page only ever hosts **one** sheet — the parent's — and the two can't stack. No `session:`-threaded `parent_pid` bridge needed: Phoenix LV exposes `socket.parent_pid` for nested mounts natively.
- Dead code removed: `UnauthCTA.connect_wallet_link/1`

**Notably NOT done in B5 (deferred):**
- Removal of `interact_login_url` helpers — still needed by the `qlinkin.bio` anon surface; retires in B6
- Tip jar standalone widget LV (`InstaTipWidgetLive`) — shipped separately; see rev 11 commit. `WalletLive` / `AdsExtLive` standalone surfaces still have pre-existing anonymous-mount issues; picked up when promoted.

**Ship criterion (met):** every unauth CTA on arcade + tip-jar native surfaces opens the sheet in place; nested arcades forward cleanly to the parent; legacy cross-domain redirects remain only on surfaces that genuinely still need them (anon-share, third-party iframe embed).

### B6 — `qlinkin.bio` fully authed surface [SHIPPED — see rev 9 + rev 10]

**Deps**: B3 (B5 recommended but not hard dep)

**Rolled out in two stages:**

**Stage 1 (shipped in rev 9, code only):**
- Qlinkin.bio host scope now uses the full `:browser` pipeline (was `:browser_anon`) and the `:mount_current_scope` on-mount hook (was `:mount_anonymous_scope`). Sessions set on qlinkin.bio are host-scoped (no `Domain=.qadabra.app`; see `HostAwareSession`) so they do NOT cross-contaminate with `.qadabra.app` sessions.
- `POST /auth/finalize_session` mounted on qlinkin.bio (host-bound `scope "/auth"` declared BEFORE the main qlinkin.bio scope so the `match :* /*path` catch-all doesn't shadow it). Uses the same JSON `:auth_finalize` pipeline as the interact-host mount.
- `DELETE /logout` explicitly mounted on qlinkin.bio (the catch-all would otherwise shadow the non-host-scoped `/logout`).
- `is_anon_surface` assign and all its dependent template branches removed from `QlinkPage.Show`. Replaced by `QlinkPage.Show.auth_sheet_enabled?/1` (picks `:on_qlinkin_bio` vs `:on_qlink_page` based on `socket.host_uri`) and `QlinkPage.Show.on_qlinkin_bio_host?/1` (template helper for the flag-OFF cross-host redirect fallback).
- Nested arcade LVs (`ArcadeLive`, `ArcadeSingleLive`) threaded through the parent's per-host decision via `session["auth_sheet_host_enabled?"]` so their inline-mode CTA gating stays in lockstep with whatever the parent will actually render.
- Dev config enables `:on_qlinkin_bio: true`; production config defaults it off pending the Cloudflare cache rule.

**Stage 2 (prod cutover, SHIPPED in rev 10):**
- Flipped `config :qlarius, :auth_sheet, on_qlinkin_bio: true` in `config/prod.exs` via a merging override (only that one key is flipped; other `:auth_sheet` defaults stay gated off separately).
- Cloudflare cache rule turned out NOT to be required — see rev 10 for the `cache-control: private` / `cf-cache-status: DYNAMIC` finding. Optional as defense-in-depth but not a prerequisite.
- `:browser_anon` pipeline retirement deferred (still used by the `qadabra.app` apex-redirect scope; leaving it in place is harmless).

**Files (stage 1):**
- edit: `lib/qlarius_web/router.ex` (qlinkin.bio host scope; `/auth/finalize_session` host-bound mount; `DELETE /logout` explicit mount)
- edit: `lib/qlarius_web/live/qlink_page/show.ex` (`auth_sheet_enabled?/1` flag-by-host; new `on_qlinkin_bio_host?/1`; dropped `is_anon_surface` assign; threaded `auth_sheet_host_enabled?` into nested arcade session)
- edit: `lib/qlarius_web/live/qlink_page/show.html.heex` (wallet stats box / drawer CTA / floating FAB cond branches all use `auth_sheet_enabled?/1` first, `on_qlinkin_bio_host?/1` fallback second, in-app `/login` fallback third)
- edit: `lib/qlarius_web/live/widgets/arcade/arcade_live.ex` + `arcade_single_live.ex` (mount reads `session["auth_sheet_host_enabled?"]`; `auth_sheet_enabled?/1` prefers that over the standalone `:on_qlink_page` flag when nested)
- edit: `config/dev.exs` (flag enabled in dev)

**Risk:**
- Cache-miss storm at stage-2 cutover for any qlinkin.bio visitors if the CF rule isn't already in place. Mitigate: ship the CF rule first, then flip the flag in a low-traffic window, monitor origin load.
- Session cookies on qlinkin.bio are host-scoped; a user authed on qlink.qadabra.app is NOT automatically authed on qlinkin.bio (they'd need to sign in once per apex). This is intentional but worth flagging in onboarding materials.

**Ship criterion (stage 1, met):** router pipeline swap deploys cleanly with prod flag off; CTA fallback path (cross-host redirect) continues to work; local dev with a hosts-file mapping for `qlinkin.bio` can open the AuthSheet in place.

**Ship criterion (stage 2):** signing in on qlinkin.bio completes in place without navigation; sessions persist across page loads on the same apex; authed viewers do NOT receive cached anonymous HTML; anon viewers still hit edge cache.

### B7 — Resume-intent plumbing (RETRACTED — see rev 11)

> **Retracted in rev 11.** The in-place AuthSheet (B2/B3) removed the original motivation: there is no page navigation to preserve intent across. Post-reconnect the same LV re-mounts, scroll is intact, every widget is still visible, and the user's previously-intercepted action is one re-click away. "Re-click the thing" proved acceptable at review, and retracting this batch deletes an entire class of bugs (stale session intent, mis-dispatch, 5-minute-window edge cases) that the design would have introduced.
>
> No code changes required to retract — B7 was never started. The `FinalizeSessionController`'s unused "stash resume in session" seam stays an unused seam; no need to remove it preemptively.
>
> If per-action resume ever becomes a real user complaint, the replacement should be an organic, feedback-driven addition — not a pre-designed dispatcher. Do not resurrect this design under a different name.

**Original scope (for historical context):**
- Define resume string vocabulary and handlers (`tip:<id>`, `buy_tiqit:<id>`, `ad_engage:<id>`, …)
- `FinalizeSessionController` stashes resume in session (§5.8)
- Create `QlariusWeb.Live.ResumeIntent` module: `parse/1`, `dispatch/2`
- Wire into `QlinkPage.Show` post-reconnect mount: read from session, dispatch, clear session key
- Wire first handlers: tip modal opener, tiqit purchase opener
- Document vocabulary for future surfaces

### B8 — Rate limits, captcha, extension exchange endpoint

**Deps**: B3

**Status:** rate-limit slice **SHIPPED (see rev 12)** — `send_code` per-phone + per-IP and `POST /auth/finalize_session` per-IP are gated by Hammer behind `config :qlarius, :auth_rate_limit, enabled?: true` (off in test). Remaining (unshipped) items: captcha, extension-exchange endpoint, invalidate-token, audit logging.

**Scope:**
- ~~Hammer rate limits on `send_code`: per-phone (3/10min), per-IP (10/hour)~~ — shipped rev 12
- ~~Hammer rate limits on `POST /auth/finalize_session`: per-IP (20/hour) to prevent token brute-forcing~~ — shipped rev 12
- Cloudflare Turnstile or similar on `send_code` after N failures in a session
- Server endpoint `POST /auth/extension_exchange` (behind `extension_exchange_enabled` flag)
- `POST /auth/invalidate_token` for logout propagation
- Device-id generation and storage in extension token
- Audit logging

**Files (shipped slice):**
- new: `lib/qlarius/auth/rate_limit.ex` (wrapper — `check_send_code_per_phone/1`, `check_send_code_per_ip/1`, `check_finalize_per_ip/1`, `format_ip/1`)
- new: `test/qlarius/auth/rate_limit_test.exs`
- edit: `lib/qlarius_web/components/auth_sheet.ex` — `client_ip` attr, gates in `send_code`, `rate_limited` reason branch in `auth:finalize_failed`
- edit: `lib/qlarius_web/controllers/auth/finalize_session_controller.ex` — per-IP gate before token verify; returns `429 {"error": "rate_limited"}`
- edit: `lib/qlarius_web/live/widgets/arcade/arcade_live.ex` + `arcade_single_live.ex` — `on_mount {GetUserIP, :assign_ip}` so standalone AuthSheet can rate-limit per-IP
- edit: 4 AuthSheet call sites thread `client_ip={assigns[:user_ip] || "0.0.0.0"}` (qlink page, insta-tip widget, arcade, arcade-single)
- edit: `config/config.exs` + `config/test.exs` — master `:auth_rate_limit, enabled?: ...` flag (on everywhere except test)

**Files (remaining):**
- new: `lib/qlarius_web/controllers/auth/extension_exchange_controller.ex`
- edit: `lib/qlarius_web/router.ex`

**Risk:** extension endpoint is a new attack surface. Mitigate with strict signature validation, origin allowlist, device binding, rate limits, audit.

**Ship criterion:** extension team (or dogfood extension instance) can exchange tokens for sessions on all three of our domains.

### B9 — Widgets as `LiveComponent`s (RETRACTED — see rev 8)

> **Retracted** in rev 8. Rationale: the motivating premise ("each nested widget opens its own WebSocket") was wrong — nested `LiveView`s share the parent's socket already, and `socket.parent_pid` lets us route events upstream without a refactor. Kept below for historical context; do not implement.

**Deps**: B1 shared primitives. Parallel-safe with B4/B6/B8. (B7 retracted in rev 11; originally listed as parallel-safe.) Blocks B5 — see sequencing note below.

**Motivation:** Today `QlinkPage.Show` embeds arcade/tipjar/sponster surfaces via `live_render/3`, each as a nested `LiveView` with its own WebSocket. On a creator's qlink page with an arcade embed plus the built-in tip jar and sponster, that's 3–4 sockets per visitor. It also means unauth CTAs inside nested widgets can't reach the parent LV's `open_auth_sheet` handler directly — §B5 had to contemplate a `parent_pid` + `send/2` bridge to work around this.

**Scope:**
- Extract arcade rendering from `ArcadeLive` / `ArcadeSingleLive` into `QlariusWeb.Components.ArcadeComponent` (`Phoenix.LiveComponent`). Covers grouped arcade, single piece, catalog/discovery as appropriate.
- Extract insta-tip / tip jar rendering from the combination of `QlariusWeb.InstaTipComponents`, `QlariusWeb.Widgets.InstaTipWidgetLive`, and Qlink's `initiate_insta_tip` path into `QlariusWeb.Components.TipJarComponent`. Consolidates a currently-scattered surface.
- (Optional within batch, or own slice) Extract sponster announcer from `AdsExtAnnouncerLive` into `QlariusWeb.Components.SponsterAnnouncerComponent`.
- Rewrite `QlinkPage.Show` so arcade/tipjar/sponster embeds render via `<.live_component>` rather than `live_render/3`. Net effect: **one WebSocket per qlink page, regardless of embed count**.
- Keep `ArcadeLive` / `ArcadeSingleLive` / `InstaTipWidgetLive` as thin **wrapper LVs** for third-party iframe embeds — their sole job becomes: parse params, mount the corresponding component, and own the PubSub subscription lifecycle for that iframe.
- Move PubSub subscriptions out of the components (LCs can't subscribe) and into the hosting LV (QlinkPage for internal; wrapper widget LV for iframes). Components become transport-agnostic; hosting LV forwards `handle_info/2` messages via `send_update/2`.
- Remove `push_event` / `push_navigate` / `redirect` calls from extracted components; route through the parent LV. (LCs can `push_event` via `Phoenix.LiveView.push_event/3` on their own socket, but navigation must go through the hosting LV.)
- As a natural consequence, `UnauthCTA.wallet_strip_or_connect/1` and `connect_wallet_modal/1` can emit plain `phx-click="open_auth_sheet"` which routes to the hosting LV — no PID bridge needed. §B5 reduces to a small template pass + dead-code cleanup.

**Files:**
- new: `lib/qlarius_web/components/arcade_component.ex` (+ any sub-components for grid / player)
- new: `lib/qlarius_web/components/tip_jar_component.ex`
- new (optional): `lib/qlarius_web/components/sponster_announcer_component.ex`
- edit: `lib/qlarius_web/live/widgets/arcade/arcade_live.ex` → thin wrapper
- edit: `lib/qlarius_web/live/widgets/arcade/arcade_single_live.ex` → thin wrapper
- edit: `lib/qlarius_web/live/widgets/insta_tip_widget_live.ex` → thin wrapper
- edit: `lib/qlarius_web/live/qlink_page/show.ex` + `.html.heex` — replace `live_render` with `live_component`
- edit: `lib/qlarius_web/widgets/unauth_cta.ex` — `phx-click` host-LV pattern
- edit: `lib/qlarius_web/components/insta_tip_components.ex` — fold into TipJarComponent or retire

**Risk:** high for a scoped refactor. Arcade LV carries real state (video player, ad events, undo counts, PubSub subs, connect modal). Mitigate with:
- Slice by component — do ArcadeComponent first, validate, then TipJarComponent
- Keep existing nested-LV embed path live behind a feature flag during cutover (`:qlink_page[:widget_embed_style] = :nested_lv | :live_component`)
- Parity test iframe embeds on third-party sites via wrapper LVs before retiring nested-LV path
- Write a before/after WebSocket-count check as part of the ship criterion

**Ship criterion:**
- A qlink page with an arcade embed + tip jar + sponster opens **one** WebSocket (verified in DevTools Network → WS)
- Arcade/tipjar widgets still function inside third-party iframes via the wrapper LVs
- Arcade behaviors preserved: video player, undo counts, PubSub-driven updates, connect-wallet modal
- Anonymous CTAs inside embedded components open AuthSheet without any PID-bridge code in the repo

### Batch sequencing

```
B1 ✓ → B2 ✓ → B3 ✓ → B5 ✓ → B6 ✓
              ├→ B4 (parallel-safe, not yet done)
              └→ B8 (parallel-safe, ideally after B3, not yet done)
```

B7 retracted in rev 11. B9 retracted in rev 8. Remaining: **B4** (proxy user sheet, parallel) and **B8** (rate limits + extension exchange endpoint).

## 7. Testing matrix

Run as a per-batch smoke gate.

### Surfaces
- qlink page on `qadabra.app` (native)
- qlink page on `qlink.qadabra.app` (native)
- qlink page on `qlinkin.bio` (native after B6)
- arqade widget inline on qlink page (native)
- arqade widget iframed (`qlarius-integration` / 3P)
- tip jar widget (inline, iframed)
- sponster announcer
- admin settings → proxy users (B4+)
- `/login` and `/register` full pages (fallbacks)

### User states
- Anon
- Signed in
- Signed in on a *different* registrable domain (cross-domain session propagation scenarios)
- Extension installed (B8+)

### Devices
- Desktop Chrome, Safari, Firefox
- Mobile Safari, Mobile Chrome
- Standalone PWA

### Core UX assertions (the hero test)
- **Unauthed, scroll to tip jar at bottom → click Tip → complete auth → page in same scroll position, wallet strip shows balance, tip modal auto-open.** Zero URL change, zero visible reload.
- Same for buy-Tiqit, ad-engage, and every other resume target.

### Edge cases
- Refresh mid-modal (each screen) — modal state lost, user re-enters phone; acceptable
- Browser back during verify step
- SMS code expires before entry
- Incorrect code → retry → correct code
- VOIP / landline / non-US phone (carrier validation rejection paths)
- Phone already registered (auto-branches to sign-in)
- Alias collision during signup
- Invalid birthdate
- Network interruption during `send_code`
- Network interruption during `/auth/finalize_session` fetch → retry UI in sheet
- Socket reconnect fails within 5s → `window.location.reload()` fallback lands user authed at top (rare)
- Exchange token replay (second use of same `jti`) → rejected
- Third-party cookie blocked (Safari ITP default) during iframe link-out round-trip
- Nested LV flicker during reconnect — subjective polish check

## 8. Rollback strategy

- Every batch gated behind per-surface feature flag (Q8 decision)
- Rollback = toggle flag + deploy
- No DB migrations in any batch → no data rollback concerns
- Cloudflare cache rule (B6) can be disabled in one click
- In-place auth can be fully bypassed by reverting the sheet to issue a classic `redirect(to: "/auto_login/:token")` via a compile-time flag if we ever need to A/B the approach

## 8.5 Dev/admin testing helper (shipped as B1.5)

**Problem:** anyone testing the registration flow on any environment hits a
hard stop the second time — their phone number is already registered.

**Solution:** when `/register`'s phone-exists check finds a user whose
`role == "admin"`, offer an "admin-only" branch: *"Admin account recognized:
`<alias>`. Create a new proxy user under this account?"*

- Verification still happens (SMS code to the admin's phone). Passing it proves
  the caller controls the admin's phone, which authorizes spawning a proxy
  beneath the admin account.
- Behind the scenes: the accepted offer flips the LV into `mode = "proxy"`
  and assigns `true_user_id = existing_user.id`. From there the existing
  `create_user/1` path (already handling `mode == "proxy"` + `true_user_id`)
  inherits the admin's referral code and calls `activate_proxy_user/2` on
  completion.
- Works in **any environment** — gated on `role == "admin"` only, so the
  same tooling supports smoke testing on staging and prod without special
  flags.
- Non-admins hitting an already-registered number still see the existing
  "log in instead" error.
- Every accepted offer logs `🧑‍💼 PROXY-VIA-REGISTRATION: admin id=... alias=...`
  for audit.

**Bonus benefit:** each test registration produces a real proxy user, which is
useful seed data for `/proxy_users`, wallet flows, and future auth-modal
verification.

**Files touched:**
- `lib/qlarius_web/live/accounts/registration_live.ex` — new `:proxy_offer_user`
  assign, `accept_proxy_offer` event handler, extracted
  `dispatch_send_verification_code/1` helper, new admin-offer card in step_one

## 9. Follow-ups / post-launch

- **Category B soft-gate** (§5.10) — auto-open `AuthSheet` on authed-consumer surfaces instead of redirecting to `/login`. Deferred until after core batches prove the sheet on Category A.
- **Retire / rewrite `/login` and `/register` full pages** to use the extracted sub-components (per Q5 note — may defer indefinitely if fallback value stays high).
- **Safari / Firefox extensions** after Chrome extension stabilizes.
- **Phone-loss recovery flow** — currently support-driven.
- **International phone support** — currently US-only.
- **Modal copy localization**.
- **Modal open telemetry** — track conversion per surface, per CTA, per device.
- **First-class "Arqade Block" type** on qlink pages (separate doc: `docs/qlink_arqade_block_followup.md`).

## 10. Open implementation questions (address at batch start, not now)

These are kicked to the appropriate batch kickoff, not blocking the plan:

- Exact `postMessage` contract for `qadabra:auth:emit-token` ↔ extension (B2 design spike)
- Where exactly the "Add proxy user" button lives (B4 spike — `user_settings_live.ex` or a dedicated proxy-users LV)
- Sheet transition animations for iframe-detection reversal (B2 polish)
- Whether to use ETS or Cachex for the `jti` single-use tracking (B2 decision; default: ETS with a named table + scheduled TTL sweep)
- Whether nested LVs need explicit "reconnecting" UI polish or the default LV loading state suffices (B2 measurement)

---

## Appendix A — Files likely touched

**New:**
- `lib/qlarius_web/components/auth_sheet.ex`
- `lib/qlarius_web/components/auth_sheet/*.html.heex`
- `lib/qlarius_web/components/proxy_user_sheet.ex`
- `lib/qlarius_web/components/proxy_user_sheet/*.html.heex`
- `lib/qlarius_web/components/auth_steps.ex`
- `lib/qlarius/referrals/context.ex`
- `lib/qlarius_web/controllers/auth/finalize_session_controller.ex`
- `lib/qlarius_web/controllers/auth/extension_exchange_controller.ex`
- ~~`lib/qlarius_web/live/resume_intent.ex`~~ (B7 retracted in rev 11)
- `assets/js/hooks/auth_finalize.js`
- `assets/js/hooks/iframe_detect.js`
- `assets/js/hooks/extension_bridge.js` (B8)

**Edited:**
- `lib/qlarius_web/live/accounts/registration_live.ex`
- `lib/qlarius_web/live/accounts/login_live.ex`
- `lib/qlarius_web/live/qlink_page/show.ex` + `.html.heex`
- `lib/qlarius_web/live/user_settings_live.ex`
- `lib/qlarius_web/widgets/unauth_cta.ex`
- `lib/qlarius_web/user_auth.ex` (add `log_in_user_from_finalize/2`)
- `lib/qlarius_web/router.ex`
- `lib/qlarius/qlink/urls.ex`
- arqade / tip jar / sponster widget templates
- `assets/js/app.js`
- `config/runtime.exs`

## Appendix B — Existing primitives we reuse (no changes)

| Primitive | Location | Purpose |
|---|---|---|
| `Qlarius.Services.Twilio.send_verification_code/1` | `lib/qlarius/services/twilio.ex` | SMS code send |
| `Qlarius.Services.Twilio.verify_code/2` | same | SMS code verify |
| `Qlarius.Services.Twilio.validate_carrier/1` | same | VOIP/landline/non-US rejection |
| `Qlarius.Auth.get_user_by_phone/1` | `lib/qlarius/auth.ex` | Phone lookup |
| `Qlarius.Accounts.register_new_user/2` | `lib/qlarius/accounts.ex` | User creation with referral |
| `Qlarius.Accounts.generate_user_login_token/1` | same | One-shot login token (used by `/login` fallback page, not by sheet) |
| `/auto_login/:token` controller | `lib/qlarius_web/controllers/session_controller.ex` (verify path) | Used only by the `/login` and `/register` full-page fallbacks. Sheet uses `/auth/finalize_session` instead. |
| `QlariusWeb.UserAuth.log_in_user/3` | `lib/qlarius_web/user_auth.ex` | Session establishment (factor helper `log_in_user_from_finalize/2` out of this in B2) |
| `QlariusWeb.HostAwareSession` | `lib/qlarius_web/plugs/host_aware_session.ex` | Per-host cookie domain |
| `QlariusWeb.Components.CustomComponentsMobile.otp_input/1` | `lib/qlarius_web/components/custom_components_mobile.ex` | Shared OTP widget |
| `QlariusWeb.Components.CustomComponentsMobile.date_input/1` | same | Shared date widget |
| `Qlarius.Accounts.AliasGenerator` | `lib/qlarius/accounts/alias_generator.ex` | Alias name + number suggestions |
| `QlariusWeb.Live.Helpers.ZipCodeLookup` | `lib/qlarius_web/live/helpers/zip_code_lookup.ex` | Zip validation |
| `Phoenix.Token` | Phoenix stdlib | Exchange token signing/verification |

## Appendix C — Revision history

- **rev 1 (2026-04-24)**: Initial plan with single `AuthSheet` component (three modes), `return_to` in public API, URL-fragment scroll preservation, redirect-based completion.
- **rev 2 (2026-04-24)**: Split into `AuthSheet` + `ProxyUserSheet`; removed `return_to` and `mode` from public APIs; in-place auth via socket reconnect (no page navigation); resume stored in session not URL param; scroll preservation is now natural (no navigation). Decision Q9 added.
- **rev 3 (2026-04-24)**: Added surface taxonomy (A/B/C categories); renamed `:on_marketer_pages` → `:on_landing_pages`; added `:on_widget_standalone` and `:on_authed_consumer` flags; new §5.10 Category B soft-gate (post-launch option); principle #9 clarifying the sheet is a discovery-surface component, not a universal auth modal.
- **rev 4 (2026-04-24)**: B1 shipped (extracted `AuthSteps` + `Referrals.Context`). B1.5 shipped — admin proxy-via-registration helper (§8.5) to unblock end-to-end registration testing across environments.
- **rev 5 (2026-04-24)**: B2 shipped — `AuthSheet` sign-in only, in-place completion wired on `QlinkPage.Show` behind `:auth_sheet[:on_qlink_page]` (on in dev only). Landed: `FinalizeToken` (signed exchange token + ETS `jti` single-use guard), `FinalizeTokenSweeper` GenServer in the app supervision tree, `UserAuth.log_in_user_from_finalize/2` (no-redirect session establishment), `POST /auth/finalize_session` controller under `:browser` pipeline, JS hooks `AuthFinalize` (fetch + `liveSocket.disconnect/connect` + 5s reload fallback) and `IframeDetect`, and the `AuthSheet` LiveComponent with phone → code → finalizing → unknown-phone link-out states + iframe interstitial. `OTPInput` hook generalized with `pushTargeted` so it works inside LiveComponents. Deferred inside B2: emitting extension identity token on finalize success (still gated by `extension_token_emit` flag; exchange endpoint not yet live — tracked for B8). Next: B3 (`AuthSheet` sign-up mode) or B4 (`ProxyUserSheet`), either parallel-safe after B2.
- **rev 7 (2026-04-24)**: Plan updated with **B9 — Widgets as `LiveComponent`s (one WebSocket per consumer surface)**. New batch extracts arcade / tip jar / sponster from nested `LiveView`s (`ArcadeLive`, `ArcadeSingleLive`, `InstaTipWidgetLive`, `AdsExtAnnouncerLive`) into `LiveComponent`s hosted by whichever LV is appropriate (QlinkPage for internal, thin wrapper LVs for third-party iframe embeds). Collapses the qlink-page-with-embeds socket count from 3–4 down to 1, and makes §B5 a template pass rather than a cross-LV event-bridging problem. Sequencing diagram updated to insert B9 between B3 and B5; §B5 scope now documents both "after B9" and "tactical before B9" paths explicitly, with the tactical path flagged as ~30 lines of throwaway. Motivated by architectural observation (per-page single WebSocket, widgets are either directly-used components or iframe-wrapped for third parties) rather than by any auth constraint — but the auth refactor's B5 becomes cleaner as a side effect.
- **rev 6 (2026-04-24)**: B3 shipped — `AuthSheet` sign-up mode folded into the same component as B2. State machine extended with `:alias → :data → :confirm → :creating` steps and the `:unknown_phone` link-out fallback retired on the qlink surface (iframe interstitial still owns that surface). Carrier validation (`Twilio.validate_carrier/1`) now runs inside `verify_code` after OTP success, mirroring `RegistrationLive`; on unknown phone we lazy-init the sign-up assigns (trait lookups, alias generator output, zip lookup) and auto-transition to `:alias`. Ported `select_base_name`, `select_number`, `regenerate_base_names`, `regenerate_numbers` (with Hammer rate limits per-phone), `select_sex`, `update_birthdate` (+ local `validate_birthdate/1` with age-trait lookup), `lookup_zip_code` via `ZipCodeLookup`, `toggle_confirmation`, and a `submit_signup` that calls `Accounts.register_new_user/2` and — on success — issues a `FinalizeToken` for the newly-created user to reuse the B2 in-place finalize path (no `/auto_login/:token` redirect). Referral capture wired inherently: `QlinkPage.Show` builds `Referrals.Context.from_creator/1` from `page.creator.users` and threads it into `AuthSheet`; `confirm_step` renders the inherited code and it's passed to `register_new_user/2` so the `referrals` row links the new user back to the creator. `DateInput` JS hook generalized with `pushTargeted` (same pattern as `OTPInput`) so `update_birthdate` routes to the LiveComponent. Admin-phone-verify / proxy-offer branch deliberately excluded — that stays with `ProxyUserSheet` in B4. Next: B4 (`ProxyUserSheet`) or B5 (widget surfaces adopt AuthSheet via `target="_top"` break-out); both parallel-safe.
- **rev 8 (2026-04-24)**: B5 scope corrected + shipped (arcade + tip-jar surfaces). Recon revealed **qlink pages already use nested `LiveView`s** (not iframes) for arcade embeds, and **tip jar + sponster + wallet strip + three-tap stack are already native** (function components / `LiveComponent`s) inside `QlinkPage.Show` — so the "widgets need a WebSocket / event-bubble refactor" framing in rev 7 was based on a misread. **B9 retracted.** Nested arcade LVs share the same WebSocket as the parent qlink page (LV nesting shares the socket, just not the process). What actually needed changing was the `UnauthCTA` redirect links. Approach: rather than bridging events from the nested arcade LV to the parent's `AuthSheet`, each LV that renders `UnauthCTA` components **hosts its own `AuthSheet` LiveComponent**. Because the `AuthFinalize` JS hook does `liveSocket.disconnect/connect` on successful sign-in, every LV on the page (parent qlink page + nested arcade) re-mounts with the authed session — so there's nothing to coordinate across processes. Shipped: `UnauthCTA.wallet_strip_or_connect/1` and `UnauthCTA.connect_wallet_modal/1` gain an `on_click` attr (JS command; when set, CTA is a `phx-click` button; when nil, legacy redirect link — kept for third-party iframe embeds and the anon-share host); `InstaTipComponents.insta_tip_card/1` forwards via `on_auth_click`; `QlinkPage.Show`'s `connect_wallet_modal` wired to `open_auth_sheet` when `auth_sheet_enabled?/1` is true (and `open_auth_sheet` handler also closes `show_connect_modal` to avoid modal-stacking); `ArcadeLive` + `ArcadeSingleLive` each mount their own `AuthSheet` gated behind a context-aware `auth_sheet_enabled?/1` (inline? → reuse `:on_qlink_page`, standalone → `:on_widget_standalone`), with `show_auth_sheet`/`auth_referral_context` assigns and `open_auth_sheet`/`close_auth_sheet` handlers. Dead code removed: `UnauthCTA.connect_wallet_link/1`. Dev config: `on_widget_standalone: true` added so standalone arcade widgets pick up AuthSheet locally. Deferred: `InstaTipWidgetLive` (standalone tip-jar widget, has pre-existing issue with anonymous mount — unrelated to B5, picked up separately); `WalletLive` + `AdsExtLive` standalone widget surfaces (CTAs not yet audited; same pattern will apply). Next: smoke test; then B6 (qlinkin.bio interactive host becomes auth-capable so the current `target="_top"` redirect path can be retired on iframe surfaces too).
- **rev 12 (2026-04-25)**: **B8 rate-limit slice shipped.** New `Qlarius.Auth.RateLimit` wrapper owns three gates: `check_send_code_per_phone/1` (3/10min, stops Twilio bill abuse — primary motivation, every allowed attempt is a paid SMS), `check_send_code_per_ip/1` (10/hour, caps mass-phone enumeration from a single client), `check_finalize_per_ip/1` (20/hour, caps `POST /auth/finalize_session` token brute-force before cryptographic verification burns cycles + ETS bucket space). All backed by the existing global `config :hammer` ETS backend; each returns `:ok | {:error, {:rate_limited, retry_after_seconds}}`. Gated by a single master flag `config :qlarius, :auth_rate_limit, enabled?: true` (off in `config/test.exs` so test suites don't share Hammer buckets across runs; individual tests opt back in via `Application.put_env/3` + `on_exit/1`). `AuthSheet` LC grew a `:client_ip` attr (defaults `"0.0.0.0"`, which `RateLimit` treats as "unknown, skip per-IP gate" — prevents all-unknown-IP traffic lumping into a single lockout bucket); all four call sites (qlink page, insta-tip widget, arcade, arcade-single) thread `assigns[:user_ip]` through. Arcade + arcade-single LVs gained `on_mount {QlariusWeb.GetUserIP, :assign_ip}` (standalone widget context; nested embeds on Qlink pages don't host their own AuthSheet but the hook is harmless). `send_code` event runs per-phone then per-IP — rate-limit hits surface as a user-visible `mobile_number_error` ("Too many attempts. Try again in about N minutes."); phone-masked log line (`****1234`) on every deny for support correlation. `FinalizeSessionController.create/2` checks per-IP before `FinalizeToken.verify_and_consume/1`, returns `429 {"error": "rate_limited"}`; existing `AuthFinalize` JS hook already propagates the body's `error` field to the LC as `auth:finalize_failed`'s `reason`, so the LC picks up `"rate_limited"` and shows a distinct "Too many sign-in attempts from this device. Try again in about an hour." message. 10 unit tests cover allow/deny transitions, independent bucket keying, IP-skip behavior for unknown IPs, the `enabled?` short-circuit, and `format_ip/1` tuple→string conversion. **Deferred** from B8 (not yet shipped; parallel-safe with any remaining batch): captcha after N failures (probably Turnstile), `POST /auth/extension_exchange`, `POST /auth/invalidate_token`, device-id generation + binding, audit logging. Remaining active batches: B4 (`ProxyUserSheet`), B8-rest (captcha + extension exchange + invalidate + audit).

- **rev 11 (2026-04-25)**: **B7 retracted.** Ancillary shipped: tipjar surfaces (`InstaTipWidgetLive` standalone + `insta_tip_card` embedded on Qlink pages) now open the in-place `AuthSheet` instead of redirecting via `interact_login_url`. Closes the B5 "deferred" note on `InstaTipWidgetLive`'s pre-existing anonymous-mount issue (guarded `current_scope.user` accesses in `mount/3` + PubSub subscribe). Uses the same `wallet_strip_or_connect/1` + `connect_wallet_modal/1` + `AuthSheet` LC trio arcade shipped in B5 — no new components; DRY via the existing `on_auth_click` passthrough on `insta_tip_card/1`. Qlink's `render_link/1` gained an `on_auth_click` attr so the two `<.render_link>` call sites in `show.html.heex` can compute `JS.push("open_auth_sheet")` where `auth_sheet_enabled?/1` has per-host flag + scope in scope. **B7 retraction rationale:** original premise (preserve user intent across a sign-in navigation) was dissolved by the in-place AuthSheet — post-reconnect, the same LV re-mounts with authed session, scroll intact, every widget visible, previously-intercepted action one re-click away. "Re-click the thing" proved acceptable at review; retracting deletes the stale-intent / mis-dispatch / window-expiry bug classes the design would have introduced. §5.8 + §5.9 edits thread this through: §5.8 marked RETRACTED with reasoning (kept as historical context); §5.9 dropped resume-stash-on-finalize + auto-dispatch-on-mount from the detailed flow description. Sequencing diagram simplified. `WalletLive` / `AdsExtLive` standalone widgets still pending — same anon-mount issue, same pattern will apply when promoted. Remaining active batches: B4 (`ProxyUserSheet`), B8 (rate limits + extension exchange). No user-facing commitment on organic follow-ups; if per-action resume becomes a real complaint, it should come in feedback-driven, not as a resurrection of the B7 design.

- **rev 10 (2026-04-24)**: B6 stage 2 shipped — `config :qlarius, :auth_sheet, on_qlinkin_bio: true` added to `config/prod.exs` (keyword-list merge, flips only this one key). **Cloudflare cache rule correction:** rev 9 flagged the CF "bypass cache on `_qlarius_key` cookie" rule as a stage-2 prerequisite. Verified against live qlinkin.bio with `curl -I` and found Phoenix already emits `cache-control: max-age=0, private, must-revalidate` on every response (session-touching plugs — `:fetch_session` + `:protect_from_forgery` — set this via `Set-Cookie` side effects). Cloudflare honors `private` and every response comes back `cf-cache-status: DYNAMIC`. So authed HTML was never at risk of being served to anon viewers via the edge, and the CF rule turned out to be optional — useful as defense-in-depth if anyone ever overrides that cache-control header for perf reasons, but not a blocker. Prod flag flipped without it. `config/prod.exs` comment expanded to document this finding. B6 is now fully shipped end-to-end. Next: monitor for ~24h; then B4 (`ProxyUserSheet`) or B7 (audit remaining `interact_login_url`/`interact_url` callers and retire).

- **rev 9 (2026-04-24)**: B6 stage 1 shipped — qlinkin.bio becomes an interactive, auth-capable surface at the router layer, with the `AuthSheet` rendered behind the `:auth_sheet[:on_qlinkin_bio]` flag (on in dev; OFF in production config, pending stage 2). **Router:** qlinkin.bio host scope swapped from `:browser_anon` → `:browser` and `:mount_anonymous_scope` → `:mount_current_scope`; the qlinkin.bio live_session was renamed `:public_qlink_anon` → `:public_qlinkin_bio` to match. A host-bound `scope "/auth"` with `pipe_through [:auth_finalize]` was added BEFORE the main qlinkin.bio scope so `POST /auth/finalize_session` isn't shadowed by the `match :* /*path` catch-all — this lets the `AuthFinalize` JS hook fetch same-origin from qlinkin.bio. `DELETE /logout` mounted explicitly on qlinkin.bio for the same reason. The `:browser_anon` pipeline stays in place (still used by the `qadabra.app` apex-redirect scope). **Session scope note:** `HostAwareSession` keeps qlinkin.bio cookies host-scoped (no `Domain=.qadabra.app`), so sessions are isolated per apex — a user authed on qlink.qadabra.app is NOT automatically authed on qlinkin.bio and vice versa. Intentional for B6. **QlinkPage.Show:** dropped the `@is_anon_surface` assign and `assign_surface_context/2` no longer computes it. `auth_sheet_enabled?/1` now picks the flag by host (`on_qlinkin_bio_host?(assigns)` → `:on_qlinkin_bio`, else `:on_qlink_page`). New public helper `on_qlinkin_bio_host?/1` is used by template CTA conds for the flag-OFF cross-host redirect fallback. `render_link/1` no longer accepts `is_anon_surface` (it was declared but never consumed). **Nested arcade threading:** `render_inline_arqade_live/3` now passes `"auth_sheet_host_enabled?"` into the nested LV's session map. `ArcadeLive` + `ArcadeSingleLive` read it at mount and stash it as `@auth_sheet_host_enabled?`; their `auth_sheet_enabled?/1` uses that parent decision when `inline?` is true (falling back to the `:on_qlink_page` flag for any older caller that doesn't pass it). This keeps the inline-arcade CTA gating in lockstep with whatever the parent will actually render on this host. **Template:** the three-way CTA conds (wallet stats, drawer "Connect your wallet", floating FAB) all flipped to `auth_sheet_enabled?/1` first, `on_qlinkin_bio_host?/1` second (kept as a safety-net so prod flag-off continues to redirect cross-host), `/login` in-app third. **Kept intentionally (will retire in stage 2 or B8):** `Qlarius.Qlink.Urls.interact_login_url/1` + `interact_url/1` are still used by the qlinkin.bio flag-OFF fallback and by `UnauthCTA` components in third-party iframe embeds. **Stage 2 (still TODO):** (a) add the Cloudflare cache rule "bypass cache when `_qlarius_key` cookie is present on qlinkin.bio", (b) flip prod `:on_qlinkin_bio: true`. Without (a), authed visitors may be served stale anon HTML by the edge cache.
