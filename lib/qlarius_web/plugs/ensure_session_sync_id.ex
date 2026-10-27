defmodule QlariusWeb.Plugs.EnsureSessionSyncId do
  @moduledoc """
  Ensures every browser session has a stable `:session_sync_id` used to
  PubSub-sync auth across same-origin LiveViews / widget iframes.

  With `accept_query: true` (the `:widgets` pipeline), a UUID `sync_id`
  query param seeds the id when the session has none. Browsers that block
  third-party cookies drop the widget session cookie, so without this each
  iframe on a publisher page would get its own id and never hear about a
  sign-in in a sibling. The embed loader scripts mint one id per host page
  and pass it to every widget iframe.

  The resolved id is also assigned to `conn.assigns.session_sync_id` so the
  root layout can sign it into the widget socket token.
  """

  import Plug.Conn

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def init(opts), do: Keyword.get(opts, :accept_query, false)

  def call(conn, accept_query?) do
    case get_session(conn, :session_sync_id) do
      id when is_binary(id) and id != "" ->
        assign(conn, :session_sync_id, id)

      _ ->
        id = query_sync_id(conn, accept_query?) || Ecto.UUID.generate()

        conn
        |> put_session(:session_sync_id, id)
        |> assign(:session_sync_id, id)
    end
  end

  defp query_sync_id(conn, true) do
    case conn.query_params do
      %{"sync_id" => id} when is_binary(id) ->
        if Regex.match?(@uuid, id), do: String.downcase(id), else: nil

      _ ->
        nil
    end
  end

  defp query_sync_id(_conn, _), do: nil
end
