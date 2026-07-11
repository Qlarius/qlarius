# Testing MCP connectors against localhost (ngrok tunnel)

How to point a Claude (or other MCP) connector at your local dev server
instead of deploying to prod for every iteration.

**Static domain (already claimed):** `languorously-flawiest-leopoldo.ngrok-free.dev`

Because the domain is static, the Claude connector survives across dev
sessions: add it once, reconnect any time both terminals are up. A random
ngrok URL would force a delete + re-add + re-OAuth of the connector on every
ngrok restart.

## Each dev session

Two terminals:

```sh
# Terminal 1 - the app, advertising the tunnel origin
PUBLIC_HOST=languorously-flawiest-leopoldo.ngrok-free.dev mix phx.server

# Terminal 2 - the tunnel, pointed at the HTTPS listener
ngrok http --domain=languorously-flawiest-leopoldo.ngrok-free.dev https://localhost:4001
```

Details that matter:

- **`PUBLIC_HOST` is required.** It makes every generated URL, including the
  OAuth discovery metadata (RFC 9728/8414), advertise the tunnel origin
  instead of localhost. Without it the connector's OAuth discovery gets
  localhost URLs and fails. Wired in `config/dev.exs` (endpoint `url` /
  `static_url`).
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
   Dev session cookies are already `Secure; SameSite=None` and
   `check_origin` is off, so login and LiveView work through the tunnel.

## Gotchas

- **The connector sees the local dev database.** Your dev user's MeFile, not
  prod's. Seed whatever tags the scenario needs before testing.
- **Claude may cache the tool list per connector session.** After changing
  tool descriptions or the server instructions, start a fresh chat (or
  disconnect/reconnect the connector) so it re-initializes.
- **Grant management** works as in prod: revoke or rotate from
  `/me_file/connectors` in the local app; the access log is at
  `/admin/mecp_access_log`.

## Local Qai testing (no tunnel needed)

Qai calls the provider outbound, so localhost is enough:

```sh
ANTHROPIC_API_KEY=sk-... mix phx.server
```

Then open `https://localhost:4001/qai`. Optional model overrides:
`QAI_CHEAP_MODEL`, `QAI_FRONTIER_MODEL` (defaults in `Qlarius.Qai.Router`).
