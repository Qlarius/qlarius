defmodule QlariusWeb.Plugs.MobileDetection do
  import Plug.Conn

  @mobile_ua_regex ~r/(Mobile|Android|iPhone|iPad)/i

  def init(opts), do: opts

  def call(conn, _opts) do
    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""
    is_mobile = Regex.match?(@mobile_ua_regex, user_agent)

    conn
    |> assign(:is_mobile, is_mobile)
    |> assign(:user_agent, user_agent)
    |> put_session_if_changed(:is_mobile, is_mobile)
  end

  # Rewriting an unchanged value still marks the session dirty, so every
  # response would resend the cookie and a concurrent request could clobber a
  # session change made by another request.
  defp put_session_if_changed(conn, key, value) do
    if get_session(conn, key) == value, do: conn, else: put_session(conn, key, value)
  end
end
