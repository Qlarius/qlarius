defmodule QlariusWeb.Plugs.AppCORS do
  @moduledoc """
  Path-dispatching CORS: one decision point for the two very different CORS
  postures this app needs.

  * **MeCP machine endpoints** (MCP JSON-RPC, OAuth register/token, OAuth
    discovery metadata): wildcard origin, no credentials. Remote MCP clients
    (claude.ai, ChatGPT) drive the protocol from the browser, so preflights
    arrive from origins we cannot enumerate. These routes carry no session
    cookies; auth is bearer-token only, so `*` without credentials is safe.
    `WWW-Authenticate` is exposed so browser clients can read the RFC 9728
    discovery pointer off a 401.

  * **Everything else**: the existing credentialed allowlist (app hosts plus
    runtime-configured extension IDs).

  The browser-session OAuth authorize page is deliberately NOT in the MeCP
  list: it is same-site navigation and must keep the strict posture.
  """

  @mecp_prefixes [
    "/mecp/mcp",
    "/mecp/oauth/register",
    "/mecp/oauth/token",
    "/.well-known/oauth-protected-resource",
    "/.well-known/oauth-authorization-server"
  ]

  def init(_opts) do
    %{
      mecp:
        CORSPlug.init(
          origin: "*",
          credentials: false,
          headers: ["*"],
          methods: ["GET", "POST", "OPTIONS"],
          expose: ["www-authenticate", "mcp-session-id"]
        ),
      app:
        CORSPlug.init(
          origin: &QlariusWeb.Endpoint.cors_origins/0,
          headers: ["*"],
          methods: ["GET", "POST"],
          credentials: true
        )
    }
  end

  def call(conn, %{mecp: mecp_opts, app: app_opts}) do
    if mecp_path?(conn.request_path) do
      CORSPlug.call(conn, mecp_opts)
    else
      CORSPlug.call(conn, app_opts)
    end
  end

  defp mecp_path?(path) do
    Enum.any?(@mecp_prefixes, &String.starts_with?(path, &1))
  end
end
