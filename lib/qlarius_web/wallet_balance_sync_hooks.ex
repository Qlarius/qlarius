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

  alias QlariusWeb.{LiveViewDebug, WalletBalanceSync}

  @subscribe_key :wallet_balance_sync_subscribed?
  @subscribe_attempts_key :wallet_balance_sync_attempts
  @subscribe_msg :wallet_balance_sync_subscribe
  @max_subscribe_attempts 100

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), @subscribe_msg, 0)
    end

    socket =
      attach_hook(socket, :wallet_balance_sync, :handle_info, fn
        @subscribe_msg, socket ->
          {:halt, subscribe_once(socket)}

        msg, socket ->
          if WalletBalanceSync.sync_message?(msg) do
            if LiveViewDebug.enabled?(), do: LiveViewDebug.log_wallet_sync(socket, msg)

            socket = WalletBalanceSync.apply_sync_hook(socket, msg)

            {:halt, socket}
          else
            {:cont, socket}
          end
      end)

    socket =
      attach_hook(socket, :wallet_balance_sync_event, :handle_event, fn
        "sync_wallet_balance", _params, socket ->
          {:halt, WalletBalanceSync.refetch_and_assign(socket)}

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  defp subscribe_once(socket) do
    case Map.get(socket.private, @subscribe_key) do
      true ->
        socket

      :skipped ->
        socket

      _ ->
        case wallet_user(socket) do
          nil ->
            if no_wallet_scope?(socket) do
              if LiveViewDebug.enabled?(),
                do: LiveViewDebug.log_wallet_subscribe(socket, "skipped_no_scope")

              put_private(socket, @subscribe_key, :skipped)
            else
              attempts = Map.get(socket.private, @subscribe_attempts_key, 0) + 1

              if attempts >= @max_subscribe_attempts do
                if LiveViewDebug.enabled?(),
                  do: LiveViewDebug.log_wallet_subscribe(socket, "gave_up")

                put_private(socket, @subscribe_key, :skipped)
              else
                Process.send_after(self(), @subscribe_msg, 10)

                socket
                |> put_private(@subscribe_attempts_key, attempts)
              end
            end

          _ ->
            if LiveViewDebug.enabled?(),
              do: LiveViewDebug.log_wallet_subscribe(socket, "subscribed")

            socket
            |> WalletBalanceSync.subscribe()
            |> put_private(@subscribe_key, true)
        end
    end
  end

  defp no_wallet_scope?(socket) do
    case socket.assigns[:current_scope] do
      nil -> true
      %{user: nil} -> true
      %{true_user: nil, user: nil} -> true
      _ -> false
    end
  end

  defp wallet_user(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: _user_id, me_file: %{id: _me_file_id}}} -> :ok
      %{user: %{id: _user_id}} -> :ok
      _ -> nil
    end
  end
end
