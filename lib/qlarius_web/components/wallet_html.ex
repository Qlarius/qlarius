defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  embed_templates "wallet_html/*"

  def sidebar_down_arrow(assigns) do
    ~H"""
    <div class="flex justify-around">
      <.icon name="hero-arrow-down-circle" class="h-8 w-8 text-gray-400" />
    </div>
    """
  end
end
