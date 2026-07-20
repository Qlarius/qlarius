defmodule QlariusWeb.SessionSync do
  @moduledoc """
  PubSub bus for auth changes across LiveViews that share a browser session.

  Same-origin widget iframes (tipjar, ads_ext, arcade, …) share one Phoenix
  session cookie and therefore one `session_sync_id`. `SessionSyncHooks`
  subscribes each LV; `broadcast/2` asks every subscriber to reconnect and
  remount with the new scope.

  This is the LiveView-standard alternative to a host-page `postMessage` bus.
  """

  @pubsub Qlarius.PubSub

  @doc "PubSub topic for a browser session sync id."
  def topic(sync_id) when is_binary(sync_id), do: "session_sync:#{sync_id}"

  @doc """
  Notify all LiveViews subscribed to this browser session that auth changed.

  `state` is `:authed` or `:anonymous` (informational; clients reconnect either way).
  """
  def broadcast(nil, _state), do: :ok

  def broadcast(sync_id, state) when is_binary(sync_id) and state in [:authed, :anonymous] do
    Phoenix.PubSub.broadcast(@pubsub, topic(sync_id), {:session_auth_changed, state})
  end
end
