defmodule QlariusWeb.WalletHTML do
  use QlariusWeb, :html

  embed_templates "wallet_html/*"

  attr :summary, :map, required: true
  attr :details_open, :boolean, required: true
  attr :details_section, :atom, required: true

  def wallet_summary_card(assigns) do
    summary = assigns.summary

    assigns =
      assigns
      |> assign(:activity_negative?, Decimal.compare(summary.activity_balance, 0) == :lt)
      |> assign(:activity_open?, assigns.details_open and assigns.details_section == :activity)
      |> assign(:credit_open?, assigns.details_open and assigns.details_section == :credit)

    ~H"""
    <.surface_panel class="home-stat-card home-stat-card--wallet">
      <div class="flex items-start justify-between gap-3 mb-6">
        <h2 class="text-xl font-bold tracking-tight text-base-content/50">Your wallet.</h2>
        <.icon name="hero-wallet" class="h-7 w-7 shrink-0 text-sponster-500" />
      </div>

      <div class="wallet-equation" aria-label="Spendable equals activity plus credit">
        <.wallet_metric
          amount={@summary.available_to_spend}
          label="spendable"
          class="text-sponster-400"
        />
        <span class="wallet-equation__op" aria-hidden="true">=</span>
        <.wallet_metric
          amount={@summary.activity_balance}
          label="activity"
          class={@activity_negative? && "text-warning"}
          disclose={:activity}
          disclose_open?={@activity_open?}
        />
        <span class="wallet-equation__op" aria-hidden="true">+</span>
        <.wallet_metric
          amount={@summary.credit_allowance}
          label="credit"
          class="text-info"
          disclose={:credit}
          disclose_open?={@credit_open?}
        />
      </div>

      <div
        class={["wallet-details", @details_open && "wallet-details--open"]}
        aria-hidden={to_string(!@details_open)}
      >
        <div class="wallet-details__clip">
          <%= if @details_section == :credit do %>
            <div class="space-y-4 pt-4">
              <p class="text-sm text-base-content/50 leading-relaxed">
                credit = a spending allowance available when all other funds are empty
              </p>
            </div>
          <% else %>
            <div class="space-y-4 pt-4">
              <div class="wallet-equation" aria-label="Activity total equals in-app plus cashable">
                <.wallet_metric
                  amount={@summary.activity_balance}
                  label="activity total"
                  class={@activity_negative? && "text-warning"}
                />
                <span class="wallet-equation__op" aria-hidden="true">=</span>
                <.wallet_metric
                  amount={@summary.non_payable_balance}
                  label="in-app"
                  class="text-sponster-700 dark:text-sponster-300"
                />
                <span class="wallet-equation__op" aria-hidden="true">+</span>
                <.wallet_metric
                  amount={@summary.balance_payable}
                  label="cashable"
                  class="text-sponster-500"
                />
              </div>
              <p class="text-sm text-base-content/50 leading-relaxed">
                in-app balance = activity proceeds you can spend, but not cash out <br />
                cashable = cash proceeds eligible for withdrawal
              </p>
              <p class="text-sm text-base-content/50 leading-relaxed">
                See the Activity Ledger below for details.
              </p>
              <p :if={@activity_negative?} class="text-sm text-base-content/50 leading-relaxed">
                Eligible sponsored activity can restore your activity balance.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </.surface_panel>
    """
  end

  attr :amount, :any, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  attr :size, :atom, default: :default, values: [:default, :hero]
  attr :disclose, :atom, default: nil, values: [nil, :activity, :credit]
  attr :disclose_open?, :boolean, default: false

  defp wallet_metric(assigns) do
    extra = if is_binary(assigns.class) and assigns.class != "", do: assigns.class, else: ""

    chevron_class =
      "wallet-details-toggle__chevron h-2.5 w-2.5 shrink-0" <>
        if assigns.disclose_open?, do: " rotate-180", else: ""

    assigns =
      assigns
      |> assign(:icon_class, "w-6 h-6 shrink-0 mt-0.5 opacity-70 #{extra}")
      |> assign(:disclose_aria, disclose_aria(assigns.disclose, assigns.disclose_open?))
      |> assign(:chevron_class, chevron_class)

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
        <div class="home-stat__label flex items-center gap-1.5">
          <span>{@label}</span>
          <button
            :if={@disclose}
            type="button"
            phx-click="toggle_wallet_details"
            phx-value-section={@disclose}
            class="wallet-details-toggle"
            aria-expanded={to_string(@disclose_open?)}
            aria-label={@disclose_aria}
          >
            <.icon name="hero-chevron-down" class={@chevron_class} />
          </button>
        </div>
      </div>
      <.icon :if={@icon} name={@icon} class={@icon_class} />
    </div>
    """
  end

  defp disclose_aria(:activity, true), do: "Hide activity details"
  defp disclose_aria(:activity, false), do: "Show activity details"
  defp disclose_aria(:credit, true), do: "Hide credit details"
  defp disclose_aria(:credit, false), do: "Show credit details"
  defp disclose_aria(_section, _open?), do: nil

  def sidebar_down_arrow(assigns) do
    ~H"""
    <div class="flex justify-around">
      <.icon name="hero-arrow-down-circle" class="h-8 w-8 text-gray-400" />
    </div>
    """
  end
end
