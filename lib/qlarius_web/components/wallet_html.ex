defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  embed_templates "wallet_html/*"

  attr :summary, :map, required: true
  attr :details_open, :boolean, required: true

  def wallet_summary_card(assigns) do
    summary = assigns.summary

    chevron_class =
      "wallet-details-toggle__chevron h-5 w-5 shrink-0 text-base-content/55" <>
        if assigns.details_open, do: " rotate-180", else: ""

    assigns =
      assigns
      |> assign(:activity_negative?, Decimal.compare(summary.activity_balance, 0) == :lt)
      |> assign(:chevron_class, chevron_class)

    ~H"""
    <.surface_panel class="home-stat-card home-stat-card--wallet">
      <div class="flex items-start justify-between gap-3 mb-6">
        <h2 class="text-xl font-bold tracking-tight text-base-content/50">Your wallet.</h2>
        <.icon name="hero-wallet" class="h-7 w-7 shrink-0 text-sponster-400" />
      </div>

      <div class="wallet-equation" aria-label="Spendable equals activity plus credit float">
        <div class="wallet-equation__terms">
          <.wallet_metric amount={@summary.available_to_spend} label="spendable" size={:hero} />
          <.wallet_metric
            amount={@summary.activity_balance}
            label="activity"
            class={@activity_negative? && "text-warning"}
          />
          <.wallet_metric
            amount={@summary.credit_allowance}
            label="credit float"
            class="text-info"
          />
        </div>
        <span class="wallet-equation__op wallet-equation__op--eq" aria-hidden="true">=</span>
        <span class="wallet-equation__op wallet-equation__op--plus" aria-hidden="true">+</span>
      </div>

      <div class="mt-5 flex justify-center">
        <button
          type="button"
          phx-click="toggle_wallet_details"
          class="wallet-details-toggle"
          aria-expanded={to_string(@details_open)}
          aria-label={if @details_open, do: "Hide wallet details", else: "Show wallet details"}
        >
          <.icon name="hero-chevron-down" class={@chevron_class} />
        </button>
      </div>

      <div :if={@details_open} class="mt-4 space-y-4">
        <div class="wallet-stat-grid wallet-stat-grid--3">
          <.wallet_metric
            amount={@summary.non_payable_balance}
            label="in-app"
            icon="hero-device-phone-mobile"
          />
          <.wallet_metric
            amount={@summary.balance_payable}
            label="cashable"
            icon="hero-arrow-trending-up"
            class="text-success"
          />
          <.wallet_metric
            amount={@summary.available_to_tip}
            label="tip-able"
            icon="hero-heart"
            class="text-sponster-400"
          />
        </div>
        <p class="text-sm text-base-content/50 leading-relaxed">
          Cashable is paid-ad earnings you can withdraw. In-app is demo and gift
          activity you can spend here, but not cash out.
        </p>
        <p :if={@activity_negative?} class="text-sm text-base-content/50 leading-relaxed">
          Eligible sponsored activity can restore your activity balance.
        </p>
        <p class="text-sm text-base-content/50 leading-relaxed">
          Tips use earned wallet value; credit covers a 25¢ tip at most once every 24 hours.
        </p>
      </div>
    </.surface_panel>
    """
  end

  attr :amount, :any, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  attr :size, :atom, default: :default, values: [:default, :hero]

  defp wallet_metric(assigns) do
    extra = if is_binary(assigns.class) and assigns.class != "", do: assigns.class, else: ""

    assigns = assign(assigns, :icon_class, "w-6 h-6 shrink-0 mt-0.5 opacity-70 #{extra}")

    ~H"""
    <div class="flex items-start justify-between gap-2 min-w-0">
      <div class="home-stat min-w-0">
        <span class={[
          if(@size == :hero,
            do: "wallet-stat__value wallet-stat__value--hero",
            else: "wallet-stat__value"
          ),
          @class
        ]}>
          {format_usd(@amount)}
        </span>
        <span class="home-stat__label">{@label}</span>
      </div>
      <.icon :if={@icon} name={@icon} class={@icon_class} />
    </div>
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
