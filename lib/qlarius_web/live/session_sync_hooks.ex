defmodule QlariusWeb.SessionSyncHooks do
  @moduledoc """
  Phoenix-native auth sync across same-origin LiveViews (widget iframes).

  Flow:

  1. `EnsureSessionSyncId` puts a stable id in the shared session cookie.
  2. Each connected LV subscribes to `SessionSync.topic(id)`.
  3. Login / logout calls `SessionSync.broadcast/2`.
  4. This hook `push_event`s `qadabra:reconnect-socket` so the client
     remounts with the updated session cookie (same pattern as AuthFinalize).

  Prefer this over host-page `postMessage` fan-out: one PubSub topic, no
  embed-script coordination, works tipjar ↔ ads_ext ↔ arcade either direction.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1, push_event: 3]

  alias QlariusWeb.SessionSync

  def on_mount(:default, _params, session, socket) do
    sync_id = session["session_sync_id"]

    socket =
      if connected?(socket) and is_binary(sync_id) do
        Phoenix.PubSub.subscribe(Qlarius.PubSub, SessionSync.topic(sync_id))

        socket
        |> assign(:session_sync_id, sync_id)
        |> attach_hook(:session_sync_events, :handle_info, &handle_sync_info/2)
      else
        assign(socket, :session_sync_id, sync_id)
      end

    {:cont, socket}
  end

  defp handle_sync_info({:session_auth_changed, _state}, socket) do
    {:halt, push_event(socket, "qadabra:reconnect-socket", %{})}
  end

  defp handle_sync_info(_msg, socket), do: {:cont, socket}
end

