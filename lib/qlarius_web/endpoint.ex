defmodule QlariusWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :qlarius

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_qlarius_key",
    signing_salt: "Tvun6ICt",
    same_site: "None",
    secure: true
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [:x_headers, session: @session_options],
      check_origin: [
        "https://qlarius.gigalixirapp.com",
        "https://www.qlarius.com",
        "https://qlarius.com",
        "http://localhost:4000",
        "https://localhost:4000",
        "http://localhost:4001",
        "https://localhost:4001",
        "http://127.0.0.1:4000",
        "https://127.0.0.1:4000",
        "http://127.0.0.1:4001",
        "https://127.0.0.1:4001",
        "chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen"
      ]
    ],
    longpoll: [connect_info: [:x_headers, session: @session_options]]

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
    only: QlariusWeb.static_paths()

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

  # Add CORS support - allow chrome extension and localhost
  plug CORSPlug,
    origin: [
      "http://localhost:4000",
      "https://localhost:4000",
      "http://localhost:4001",
      "https://localhost:4001",
      "https://qlarius.gigalixirapp.com",
      "chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen"
    ],
    headers: ["*"],
    methods: ["GET", "POST"],
    credentials: true

  plug QlariusWeb.Router

  defp set_csp(conn, _) do
    csp =
      "base-uri 'self'; default-src 'self'; img-src 'self' data: http: https: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' ws://localhost:* wss://localhost:* http://localhost:* https://localhost:* chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen; frame-src 'self' https://www.youtube.com https://youtube.com; frame-ancestors * chrome-extension://ambaojidcamjpjbfcnefhobgljmafgen; upgrade-insecure-requests;"

    Plug.Conn.put_resp_header(conn, "content-security-policy", csp)
  end
end
