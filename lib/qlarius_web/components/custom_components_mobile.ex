defmodule QlariusWeb.Components.CustomComponentsMobile do
  use QlariusWeb, :html

  import QlariusWeb.Money

  attr :balance, :float, required: true

  def wallet_balance(assigns) do
    ~H"""
    <div class="text-md bg-sponster-500 text-white px-3 py-1 rounded-lg">
      <span class="font-bold"><%= format_usd(@balance) %></span>
    </div>
    """
  end

end
