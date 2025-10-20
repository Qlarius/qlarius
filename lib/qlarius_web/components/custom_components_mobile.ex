defmodule QlariusWeb.Components.CustomComponentsMobile do
  use QlariusWeb, :html

  import QlariusWeb.Money

  attr :balance, :any, required: true

  def wallet_balance(assigns) do
    ~H"""
    <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500">
      <span class="font-bold">{format_usd(@balance)}</span>
    </span>
    """
  end

  attr :count, :integer, required: true

  def tag_count(assigns) do
    ~H"""
    <span class="inline-flex items-center w-auto text-lg bg-youdata-200 dark:bg-youdata-900 text-base-content px-3 py-1 rounded-lg border border-youdata-300 dark:border-youdata-500">
      <span class="font-bold">{@count}&nbsp;tags</span>
    </span>
    """
  end
end
