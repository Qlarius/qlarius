defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  embed_templates "wallet_html/*"

  attr :summary, :map, required: true
  attr :details_open, :boolean, required: true

  def wallet_summary_card(assigns) do
    ~H"""
    <.surface_panel>
      <div class="px-1 py-1">
        <p class="text-sm text-base-content/60">Available to spend</p>
        <p class="text-3xl font-semibold mt-1">
          {format_usd(@summary.available_to_spend)}
        </p>
        <p class="text-sm text-base-content/70 mt-2">
          {format_usd(@summary.activity_balance)} activity
          + {format_usd(@summary.credit_allowance)} credit allowance
        </p>
        <p
          :if={Decimal.compare(@summary.available_to_tip, @summary.available_to_spend) != :eq}
          class="text-sm text-base-content/70 mt-2"
        >
          Available to tip: {format_usd(@summary.available_to_tip)}. Tips use earned
          wallet value; credit covers a 25¢ tip at most once every 24 hours.
        </p>
        <button
          type="button"
          phx-click="toggle_wallet_details"
          class="btn btn-ghost btn-sm mt-3 px-0"
        >
          {if @details_open, do: "Hide details", else: "Show details"}
        </button>
        <div :if={@details_open} class="mt-3 space-y-1 text-sm text-base-content/70">
          <p>Activity balance: {format_usd(@summary.activity_balance)}</p>
          <p>Non-payable: {format_usd(@summary.non_payable_balance)}</p>
          <p>Payable: {format_usd(@summary.balance_payable)}</p>
          <p>
            Available amount includes earned activity and your permanent credit allowance.
          </p>
          <p :if={Decimal.compare(@summary.activity_balance, 0) == :lt}>
            Eligible sponsored activity can restore your activity balance.
          </p>
        </div>
      </div>
    </.surface_panel>
    """
  end

  def sidebar_down_arrow(assigns) do
    ~H"""
    <div class="flex justify-around">
      <.icon name="hero-arrow-down-circle" class="h-8 w-8 text-gray-400" />
    </div>
    """
  end
end
