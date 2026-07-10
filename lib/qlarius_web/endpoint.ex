defmodule QlariusWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :qlarius

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options Application.compile_env!(:qlarius, [QlariusWeb.Endpoint, :session_options])

  # Use function for check_origin: production LB/proxy can modify Origin; strict list may reject valid connections.
  # Must be applied to BOTH transports — falling back to PHX_HOST-based default on longpoll rejects qadabra.app.
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [:x_headers, :uri, session: @session_options],
      check_origin: {QlariusWeb.Endpoint, :check_ws_origin, []}
    ],
    longpoll: [
      connect_info: [:x_headers, :uri, session: @session_options],
      check_origin: {QlariusWeb.Endpoint, :check_ws_origin, []}
    ]

  # Based on https://elixirforum.com/t/how-to-embed-a-liveview-via-iframe/65066
  # This isn't a good long-term solution; I just need to get the demo working.
  # Both transports must bypass the origin check: widgets embed in
  # third-party pages whose origin is unknown at deploy time, and when
  # the browser (or a restrictive network) falls back from WS to
  # longpoll the request would otherwise be rejected against PHX_HOST.
  socket "/widgets/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [:x_headers, session: @session_options],
      check_origin: false
    ],
    longpoll: [
      connect_info: [:x_headers, session: @session_options],
      check_origin: false
    ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :qlarius,
    gzip: false,
    only: QlariusWeb.static_paths(),
    content_types: %{
      "webmanifest" => "application/manifest+json"
    }

  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug QlariusWeb.LiveViewDebug.CodeReloaderPlug
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :qlarius
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  # Shared session cookie across *.qadabra.app (login on qlink.qadabra.app
  # recognized on qadabra.app and vice versa) while staying host-scoped on
  # qlinkin.bio / localhost / etc. See `HostAwareSession` for rationale.
  plug QlariusWeb.Plugs.HostAwareSession, @session_options
  plug :set_csp

  # Base HTTP origins allowed by CORS. The browser extension IDs are
  # merged in dynamically at runtime from `:qlarius, :cors_extension_ids`
  # so dev builds can whitelist a pinned dev extension ID without
  # shipping it in the production binary. See config/dev.exs for the
  # dev list and config/config.exs for the prod-only list.
  @cors_http_origins [
    "http://localhost:4000",
    "https://localhost:4000",
    "http://127.0.0.1:4000",
    "https://127.0.0.1:4000",
    "http://10.0.2.2:4000",
    "https://qlarius.gigalixirapp.com",
    "https://qadabra.app",
    "https://www.qadabra.app",
    "https://qlink.qadabra.app",
    "https://qlinkin.bio",
    "https://www.qlinkin.bio"
  ]

  # CORSPlug 3.x accepts a 0-arity function for `:origin` and invokes it
  # per request, which lets us merge runtime-configured extension IDs
  # without recompiling. MFA tuples are NOT supported — passing one
  # crashes on every request with a FunctionClauseError.
  #
  # AppCORS dispatches by path: MeCP machine endpoints get wildcard
  # non-credentialed CORS (browser-driven MCP clients connect from origins
  # we cannot enumerate); everything else keeps the credentialed allowlist
  # below via cors_origins/0.
  plug QlariusWeb.Plugs.AppCORS

  plug QlariusWeb.Router

  @doc false
  def cors_origins do
    @cors_http_origins ++ Application.get_env(:qlarius, :cors_extension_ids, [])
  end

  # Allowed WebSocket origins. Accepts:
  #
  #   * The Qadabra apex and any `*.qadabra.app` subdomain (suffix-matched
  #     against `.qadabra.app`, so new subdomains are auto-admitted — this
  #     mirrors the shared `.qadabra.app` session cookie domain scoped by
  #     `QlariusWeb.Plugs.HostAwareSession`).
  #   * The anonymous share surface `qlinkin.bio` (+ `www.`) so public
  #     Qlink pages can hold an LV connection even though they're
  #     session-ephemeral.
  #   * Legacy `qlarius.com` / `www.qlarius.com` during the rebrand.
  #   * Any `*.gigalixirapp.com` for the hosted platform.
  #   * Dev hosts (localhost, 127.0.0.1, 10.0.2.2 for Android emulator).
  #   * Every `chrome-extension://` origin so the browser extension can
  #     open LiveView sockets from its iframe.
  def check_ws_origin(uri) do
    host = uri.host || ""

    host in [
      "qlinkin.bio",
      "www.qlinkin.bio",
      "qlarius.gigalixirapp.com",
      "www.qlarius.com",
      "qlarius.com",
      "localhost",
      "127.0.0.1",
      "10.0.2.2"
    ] or host == "qadabra.app" or String.ends_with?(host, ".qadabra.app") or
      String.ends_with?(host, ".gigalixirapp.com") or uri.scheme == "chrome-extension"
  end

  defp set_csp(conn, _) do
    Plug.Conn.put_resp_header(
      conn,
      "content-security-policy",
      QlariusWeb.SecurityHeaders.content_security_policy()
    )
  end
end
