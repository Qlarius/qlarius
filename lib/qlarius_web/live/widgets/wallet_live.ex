defmodule QlariusWeb.Widgets.WalletLive do
  use QlariusWeb, :live_view

  alias Qlarius.Wallets

  def mount(_params, _session, socket) do
    balance = Wallets.get_user_current_balance(socket.assigns.current_scope.user)
    {:ok, assign(socket, balance: balance)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-green-300 border-t border-green-800 py-4 text-gray-800 font-semibold h-16 flex items-center justify-around">
      <div>Qlarius Wallet: ${Decimal.round(@balance, 2)}</div>
    </div>
    """
  end
end
