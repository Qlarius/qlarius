defmodule QlariusWeb.Components.CustomComponentsMobile do
  use QlariusWeb, :html

  import QlariusWeb.Money

  attr :balance, :float, required: true

  def wallet_balance(assigns) do
    ~H"""
    <div class="text-md bg-sponster-200 dark:bg-sponster-800 text-base-content px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500">
      <span class="font-bold">{format_usd(@balance)}</span>
    </div>
    """
  end
end
