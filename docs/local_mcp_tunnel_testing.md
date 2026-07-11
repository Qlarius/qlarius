# Testing MCP connectors against localhost (ngrok tunnel)

How to point a Claude (or other MCP) connector at your local dev server
instead of deploying to prod for every iteration.

**Static domain (already claimed):** `languorously-flawiest-leopoldo.ngrok-free.dev`

Because the domain is static, the Claude connector survives across dev
sessions: add it once, reconnect any time both terminals are up. A random
ngrok URL would force a delete + re-add + re-OAuth of the connector on every
ngrok restart.

## One-time shell setup

In `~/.zshrc`:

```sh
# --- Qlarius dev ---
# Qai provider key (read at boot by config/runtime.exs)
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Tunnel-mode dev server + tunnel (MCP connector testing).
# Plain `mix phx.server` stays localhost-only; use these when tunneling.
alias qdev-tunnel='PUBLIC_HOST=languorously-flawiest-leopoldo.ngrok-free.dev mix phx.server'
alias qtunnel='ngrok http --domain=languorously-flawiest-leopoldo.ngrok-free.dev https://localhost:4001'
```

Then `source ~/.zshrc`. Persist only the API key globally, **not**
`PUBLIC_HOST`: a global `PUBLIC_HOST` would make every dev boot generate
URLs pointing at the tunnel even when ngrok is not running.

## Each dev session

Two terminals:

```sh
qdev-tunnel   # Terminal 1 - the app, advertising the tunnel origin
qtunnel       # Terminal 2 - the tunnel, pointed at the HTTPS listener
```

Which expand to:

```sh
PUBLIC_HOST=languorously-flawiest-leopoldo.ngrok-free.dev mix phx.server
ngrok http --domain=languorously-flawiest-leopoldo.ngrok-free.dev https://localhost:4001
```

Details that matter:

- **`PUBLIC_HOST` is required.** It makes every generated URL, including the
  OAuth discovery metadata (RFC 9728/8414), advertise the tunnel origin
  instead of localhost. Without it the connector's OAuth discovery gets
  localhost URLs and fails. Wired in `config/dev.exs` (endpoint `url` /
  `static_url`). It also makes the tunnel host a valid websocket origin
  (`QlariusWeb.Endpoint.check_ws_origin/1` accepts the advertised host), so
  LiveView pages like login work through the tunnel.
- **Tunnel to `https://localhost:4001`, not `:4000`.** Dev `force_ssl` 301s
  non-localhost hosts off the plain-HTTP listener, which breaks the tunnel.
  ngrok does not verify the local mkcert cert, so the HTTPS upstream just
  works.

## Adding the connector in Claude

MCP server URL:

```
https://languorously-flawiest-leopoldo.ngrok-free.dev/mecp/mcp
```

The OAuth flow runs against the local server. Expect:

1. ngrok's free-tier interstitial page once in the browser ("You are about
   to visit...") - click Visit Site.
2. Log into the **local** app through the tunnel, then approve the grant.
   Dev session cookies are already `Secure; SameSite=None`, so the session
   works over the tunnel origin.

## Gotchas

- **The connector sees the local dev database.** Your dev user's MeFile, not
  prod's. Seed whatever tags the scenario needs before testing.
- **Claude may cache the tool list per connector session.** After changing
  tool descriptions or the server instructions, start a fresh chat (or
  disconnect/reconnect the connector) so it re-initializes.
- **Env vars are read at boot.** A server started before `ANTHROPIC_API_KEY`
  or `PUBLIC_HOST` was set never sees them; restart `mix phx.server`.
- **Grant management** works as in prod: revoke or rotate from
  `/me_file/connectors` in the local app; the access log is at
  `/admin/mecp_access_log`.

## Local Qai testing (no tunnel needed)

Qai calls the provider outbound, so localhost is enough. With
`ANTHROPIC_API_KEY` exported in the shell (one-time setup above), a plain

```sh
mix phx.server
```

is fully configured. Open `https://localhost:4001/qai`. Optional model
overrides: `QAI_CHEAP_MODEL`, `QAI_FRONTIER_MODEL` (defaults in
`Qlarius.Qai.Router`).
