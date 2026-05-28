defmodule QlariusWeb.WalletBalanceSyncHooks do
  @moduledoc """
  Global LiveView hook: subscribe to wallet PubSub topics and refresh
  `wallet_balance` / `wallet_strip` assigns on balance events.

  Subscription is deferred via `Process.send_after/3` so `current_scope` from
  `live_session` `on_mount` is available first. We intentionally avoid a
  `handle_params` hook because nested child LiveViews (e.g. arqade embeds via
  `live_render/3`) cannot use `handle_params/3`.
  """

  import Phoenix.LiveView

  alias QlariusWeb.WalletBalanceSync

  @subscribe_key :wallet_balance_sync_subscribed?
  @subscribe_msg :wallet_balance_sync_subscribe

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), @subscribe_msg, 0)
    end

    socket =
      attach_hook(socket, :wallet_balance_sync, :handle_info, fn
        @subscribe_msg, socket ->
          {:halt, subscribe_once(socket)}

        msg, socket ->
          if WalletBalanceSync.wallet_message?(msg) do
            {:halt, WalletBalanceSync.handle_info_message(msg, socket)}
          else
            {:cont, socket}
          end
      end)

    {:cont, socket}
  end

  defp subscribe_once(socket) do
    if Map.get(socket.private, @subscribe_key) do
      socket
    else
      socket
      |> WalletBalanceSync.subscribe()
      |> put_private(@subscribe_key, true)
    end
  end
end
