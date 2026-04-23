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
  socket "/widgets/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [:x_headers, session: @session_options],
      check_origin: false
    ],
    longpoll: [connect_info: [:x_headers, session: @session_options]]

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
    plug Phoenix.CodeReloader
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
  plug Plug.Session, @session_options
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
  plug CORSPlug,
    origin: &__MODULE__.cors_origins/0,
    headers: ["*"],
    methods: ["GET", "POST"],
    credentials: true

  plug QlariusWeb.Router

  @doc false
  def cors_origins do
    @cors_http_origins ++ Application.get_env(:qlarius, :cors_extension_ids, [])
  end

  # Allowed WebSocket origins. Includes all production hosts (qadabra.app
  # apex and subdomains, qlinkin.bio, legacy qlarius.com and
  # qlarius.gigalixirapp.com), dev hosts (localhost, 127.0.0.1, 10.0.2.2
  # for Android emulator), and all chrome-extension:// origins so the
  # browser extension can open LiveView sockets from its iframe.
  def check_ws_origin(uri) do
    host = uri.host || ""

    host in [
      "qadabra.app",
      "www.qadabra.app",
      "qlink.qadabra.app",
      "qlinkin.bio",
      "www.qlinkin.bio",
      "qlarius.gigalixirapp.com",
      "www.qlarius.com",
      "qlarius.com",
      "localhost",
      "127.0.0.1",
      "10.0.2.2"
    ] or String.ends_with?(host, ".gigalixirapp.com") or uri.scheme == "chrome-extension"
  end

  defp set_csp(conn, _) do
    csp =
      "base-uri 'self'; default-src 'self'; img-src 'self' data: http: https: blob:; media-src 'self' http://localhost:4000 https://localhost:4001 https://*.s3.us-east-1.amazonaws.com https://*.s3.amazonaws.com; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' ws: wss: http: https:; frame-src 'self' https://qadabra.app https://*.qadabra.app https://qlinkin.bio https://*.qlinkin.bio https://qlarius.gigalixirapp.com https://www.youtube.com https://youtube.com https://www.youtube-nocookie.com https://open.spotify.com https://www.tiktok.com https://tiktok.com; frame-ancestors * chrome-extension:;"

    Plug.Conn.put_resp_header(conn, "content-security-policy", csp)
  end
end
