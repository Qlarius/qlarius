defmodule QlariusWeb.InstaTipComponents do
  use QlariusWeb, :html

  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Money, only: [format_usd: 1]

  attr :wallet_balance, :any, required: true

  def insta_tip_header(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col items-center md:items-start mt-0">
      <div class="text-lg font-bold text-base-content mb-1">InstaTip</div>
      <div class="text-base-content/70 text-sm mb-4">
        Instantly tip from your wallet <.icon name="hero-arrow-right" class="w-4 h-4 inline-block" />
        <.wallet_balance balance={@wallet_balance} />
      </div>
    </div>
    """
  end

  attr :amounts, :list, required: true
  attr :target, :any, default: nil

  def insta_tip_button_group(assigns) do
    ~H"""
    <div class="flex gap-3 justify-center">
      <%= for amount <- @amounts do %>
        <button
          type="button"
          phx-click="initiate_insta_tip"
          phx-target={@target}
          phx-value-amount={amount}
          class="btn btn-circle btn-primary btn-lg font-bold hover:btn-primary-focus p-8"
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
          <h2 class="text-xl font-bold text-base-content">Confirm InstaTip</h2>
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
          <div class="flex justify-between">
            <span class="text-sm text-base-content/70">Current Balance:</span>
            <span class="font-medium">{format_usd(@current_balance)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-base-content/70">After Tip:</span>
            <span class="font-medium">
              {format_usd(Decimal.sub(@current_balance, @amount))}
            </span>
          </div>
        </div>

        <div class="flex gap-3">
          <button
            type="button"
            phx-click="confirm_insta_tip"
            phx-value-amount={@amount}
            class="btn btn-primary flex-1"
          >
            Send Tip
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
