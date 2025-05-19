defmodule QlariusWeb.Widgets.WalletLive do
  use QlariusWeb, :live_view

  alias Qlarius.Wallets.Wallets

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    balance = Wallets.get_user_current_balance(user)
    Phoenix.PubSub.subscribe(Qlarius.PubSub, "wallet:#{user.id}")
    {:ok, assign(socket, balance: balance)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-green-300 border-t border-green-800 py-4 text-gray-800 font-semibold h-16 flex items-center justify-around">
      <div>Qlarius Wallet: ${Decimal.round(@balance, 2)}</div>
    </div>
    """
  end

  def handle_info(:update_balance, socket) do
    user = socket.assigns.current_scope.user
    balance = Wallets.get_user_current_balance(user)
    {:noreply, assign(socket, balance: balance)}
  end
end
