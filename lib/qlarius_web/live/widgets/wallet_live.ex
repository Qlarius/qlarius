defmodule QlariusWeb.Widgets.WalletLive do
  use QlariusWeb, :live_view

  alias Qlarius.Wallets

  # Anonymous visitors (no cookie, no widget token) mount with
  # `current_scope: nil`; render a connect prompt instead of crashing.
  def mount(_params, _session, socket) do
    case socket.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user.id}")
        end

        {:ok, assign(socket, balance: Wallets.get_user_current_balance(user))}

      _ ->
        {:ok, assign(socket, balance: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="bg-green-300 border-t border-green-800 py-4 text-gray-800 font-semibold h-16 flex items-center justify-around">
      <div :if={@balance}>Qlarius Wallet: ${Decimal.round(@balance, 2)}</div>
      <div :if={is_nil(@balance)}>Connect to see your Qlarius Wallet</div>
    </div>
    """
  end

  def handle_info(:update_balance, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:noreply, assign(socket, balance: Wallets.get_user_current_balance(user))}
  end

  def handle_info(:update_balance, socket), do: {:noreply, socket}
end
