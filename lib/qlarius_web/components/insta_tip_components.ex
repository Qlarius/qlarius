defmodule QlariusWeb.InstaTipComponents do
  use QlariusWeb, :html

  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Money, only: [format_usd: 1]

  attr :wallet_balance, :any, required: true
  attr :add_class, :string, default: nil

  def insta_tip_header(assigns) do
    ~H"""
    <div class={["flex-1 flex flex-col items-center md:items-start mt-0", @add_class]}>
      <div class="text-base-content/70 text-sm mt-3 mb-4">
        From your wallet <.icon name="hero-arrow-right" class="w-4 h-4 inline-block" />
        <.wallet_balance balance={@wallet_balance} />
      </div>
    </div>
    """
  end

  attr :amounts, :list, required: true
  attr :wallet_balance, :any, required: true
  attr :target, :any, default: nil
  attr :add_class, :string, default: nil

  def insta_tip_button_group(assigns) do
    ~H"""
    <div class={["grid grid-cols-2 sm:grid-cols-4 gap-3 justify-items-center", @add_class]}>
      <%= for amount <- @amounts do %>
        <%
          amount_decimal = Decimal.new(amount)
          enabled = Decimal.compare(@wallet_balance, amount_decimal) != :lt
        %>
        <button
          type="button"
          phx-click="initiate_insta_tip"
          phx-target={@target}
          phx-value-amount={amount}
          disabled={!enabled}
          class={[
            "btn btn-circle btn-lg font-bold p-8",
            if(enabled, do: "btn-primary hover:btn-primary-focus", else: "btn-disabled")
          ]}
        >
          <span>
            <%= case to_string(amount) do %>
              <% "2.00" -> %>
                $2
              <% "1.00" -> %>
                $1
              <% "0.50" -> %>
                50¢
              <% "0.25" -> %>
                25¢
              <% _ -> %>
                ${amount}
            <% end %>
          </span>
        </button>
      <% end %>
    </div>
    """
  end

  attr :show, :boolean, default: false
  attr :recipient_name, :string, required: true
  attr :amount, :any, required: true
  attr :current_balance, :any, required: true

  def insta_tip_modal(assigns) do
    ~H"""
    <.modal :if={@show} id="insta-tip-modal" show on_cancel={JS.push("close-insta-tip-modal")}>
      <div class="text-center space-y-6 p-8">
        <div class="space-y-4">
          <h2 class="text-xl font-bold text-base-content">Confirm Tip</h2>
          <div class="text-center">
            <div class="text-3xl font-bold text-primary mb-2">
              {format_usd(@amount)}
            </div>
            <div class="text-base-content/70">
              to <span class="font-semibold">{@recipient_name}</span>
            </div>
          </div>
        </div>

        <div class="bg-base-200 rounded-lg p-4 space-y-2">
          <div class="flex justify-between items-center">
            <span class="text-sm text-base-content/70">Wallet:</span>
            <.wallet_balance balance={@current_balance} />
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-base-content/70">After Tip:</span>
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content/60 px-3 py-1 ml-3 rounded-lg border border-dashed border-sponster-500 dark:border-sponster-500">
              <span class="font-bold opacity-80">
                {format_usd(Decimal.sub(@current_balance, @amount))}
              </span>
            </span>
          </div>
        </div>

        <div class="flex gap-3">
          <button
            type="button"
            phx-click="confirm_insta_tip"
            phx-value-amount={@amount}
            class="btn btn-primary flex-1 font-bold rounded-full"
          >
            TIP
          </button>
          <button type="button" phx-click="close-insta-tip-modal" class="btn btn-ghost flex-1">
            Cancel
          </button>
        </div>
      </div>
    </.modal>
    """
  end
end
