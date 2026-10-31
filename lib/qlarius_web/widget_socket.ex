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

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  @doc """
  The session LiveView will mount with.

  A cookie session that names a user wins. Otherwise a user-bearing
  `widget_token` (`:authed` / `:session`) takes over — browsers with
  per-site ephemeral cookie jars (Brave) do send a cookie, just an
  anonymous one, and it must not shadow a valid token. With neither, the
  anonymous cookie session or the `:anon` token session is used; a refused
  token is flagged with `"widget_token_refused"` so the client drops it.

  A `:session` token the client kept from an earlier page load carries
  that page's sync id. The loader mints a fresh id per host page load, so
  a `sync_id` connect param (the same UUID the iframe URL carries) replaces
  the token's id and keeps sibling widgets on one PubSub topic.
  """
  @spec session_from(map(), map()) :: map()
  def session_from(params, connect_info) do
    cookie = Map.get(connect_info, :session)

    if is_map(cookie) and is_binary(cookie["user_token"]) do
      cookie
    else
      case WidgetToken.verify(params["widget_token"]) do
        {:ok, %{kind: kind} = payload} when kind in [:authed, :session] ->
          payload |> WidgetToken.session_for() |> put_param_sync_id(params)

        {:ok, payload} when is_map(cookie) ->
          cookie |> Map.put_new("session_sync_id", payload.sync_id) |> drop_nil()

        {:ok, payload} ->
          WidgetToken.session_for(payload)

        {:error, _} ->
          flag_refused(if(is_map(cookie), do: cookie, else: %{}), params["widget_token"])
      end
    end
  end

  defp flag_refused(session, token) when is_binary(token) and token != "" do
    Map.put(session, "widget_token_refused", true)
  end

  defp flag_refused(session, _token), do: session

  defp drop_nil(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

  defp put_param_sync_id(session, %{"sync_id" => id}) when is_binary(id) do
    if Regex.match?(@uuid, id) do
      Map.put(session, "session_sync_id", String.downcase(id))
    else
      session
    end
  end

  defp put_param_sync_id(session, _params), do: session
end
