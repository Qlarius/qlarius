defmodule QlariusWeb.WalletBalanceSync do
  @moduledoc """
  PubSub subscription and assign refresh for `wallet_balance` / `wallet_strip` UI.

  LiveViews that render wallet pills should call `subscribe/1` when connected and
  delegate wallet-related `handle_info/2` messages here so every instance on the
  page receives updated assigns (announcer bar, drawer header, arqade strip, etc.).
  """

  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  @doc "Subscribe to me_file stats + wallet topics for the scoped user."
  def subscribe(socket) do
    case wallet_user(socket) do
      {user_id, me_file_id} ->
        MeFileStatsBroadcaster.subscribe_to_me_file_stats(me_file_id)
        Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user_id}")
        socket

      _ ->
        socket
    end
  end

  @doc false
  def wallet_message?({:me_file_balance_updated, _}), do: true
  def wallet_message?(:update_balance), do: true
  def wallet_message?({:refresh_wallet_balance, _}), do: true
  def wallet_message?(_), do: false

  @doc """
  Applies a known balance to socket assigns. Updates `:current_scope`, and
  `:balance` / `:current_balance` when those assigns exist (arqade strip, modals).
  """
  def assign_wallet_fields(socket, new_balance) do
    case socket.assigns[:current_scope] do
      scope when not is_nil(scope) ->
        current_scope = Map.put(scope, :wallet_balance, new_balance)

        socket
        |> assign(:current_scope, current_scope)
        |> maybe_assign(:current_balance, new_balance)
        |> maybe_assign(:balance, new_balance)

      _ ->
        socket
    end
  end

  @doc "Refetch balance from the database and apply to assigns."
  def refetch_and_assign(socket) do
    case socket.assigns[:current_scope] do
      %{user: user} ->
        assign_wallet_fields(socket, Wallets.get_user_current_balance(user))

      _ ->
        socket
    end
  end

  @doc "Route a wallet PubSub message to the appropriate assign refresh."
  def handle_info_message({:me_file_balance_updated, new_balance}, socket) do
    assign_wallet_fields(socket, new_balance)
  end

  def handle_info_message(:update_balance, socket), do: refetch_and_assign(socket)

  def handle_info_message({:refresh_wallet_balance, _me_file_id}, socket),
    do: refetch_and_assign(socket)

  defp wallet_user(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: user_id, me_file: %{id: me_file_id}}} -> {user_id, me_file_id}
      _ -> nil
    end
  end

  defp assign(socket, key, value), do: Phoenix.Component.assign(socket, key, value)

  defp maybe_assign(socket, key, value) do
    if Map.has_key?(socket.assigns, key), do: assign(socket, key, value), else: socket
  end
end
