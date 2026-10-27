defmodule QlariusWeb.WidgetSocket do
  @moduledoc """
  LiveView socket for `/widgets/live`.

  Widget iframes sit on publisher sites, and browsers that block
  third-party cookies never send `_qlarius_key`. The stock socket then has
  a `nil` session, LiveView replies `stale`, and the client reloads the
  iframe in a loop. This socket always provides a session map: the cookie
  session when it arrived, otherwise one built from a signed
  `widget_token` param, otherwise an empty map. A missing cookie becomes an
  anonymous mount instead of a failed join.

  `check_origin` is off for this socket because publisher origins are not
  known ahead of time. Phoenix's CSRF check therefore stays on; it is what
  gates the cookie path. The token path relies on the token's signature and
  short lifetime instead.
  """

  use Phoenix.Socket

  alias QlariusWeb.Auth.WidgetToken

  channel "lvu:*", Phoenix.LiveView.UploadChannel
  channel "lv:*", Phoenix.LiveView.Channel

  @impl Phoenix.Socket
  def connect(params, socket, connect_info) do
    connect_info = Map.put(connect_info, :session, session_from(params, connect_info))
    Phoenix.LiveView.Socket.connect(params, socket, connect_info)
  end

  @impl Phoenix.Socket
  def id(socket), do: Phoenix.LiveView.Socket.id(socket)

  @doc """
  The session LiveView will mount with. The cookie session wins when the
  browser sent it and the CSRF token matched; a `widget_token` fills in
  otherwise; nothing valid means an anonymous session.
  """
  @spec session_from(map(), map()) :: map()
  def session_from(params, connect_info) do
    case Map.get(connect_info, :session) do
      session when is_map(session) ->
        session

      _ ->
        case WidgetToken.verify(params["widget_token"]) do
          {:ok, payload} -> WidgetToken.session_for(payload)
          {:error, _} -> %{}
        end
    end
  end
end
