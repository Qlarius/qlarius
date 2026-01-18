defmodule QlariusWeb.Plugs.StorePWASession do
  @moduledoc """
  Reads PWA status from cookie and stores in session.
  This allows PWA status to be available on first render (disconnected mount).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Fetch cookies if not already fetched
    conn = fetch_cookies(conn)

    # Read PWA status from cookie (set by JavaScript)
    is_pwa =
      case conn.cookies["is_pwa"] do
        "true" -> true
        _ -> false
      end

    # Store in session for LiveView access
    if is_pwa != get_session(conn, :is_pwa) do
      put_session(conn, :is_pwa, is_pwa)
    else
      conn
    end
  end
end
