defmodule QlariusWeb.Plugs.EnsureSessionSyncId do
  @moduledoc """
  Ensures every browser session has a stable `:session_sync_id` used to
  PubSub-sync auth across same-origin LiveViews / widget iframes.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :session_sync_id) do
      id when is_binary(id) and id != "" ->
        conn

      _ ->
        put_session(conn, :session_sync_id, Ecto.UUID.generate())
    end
  end
end
