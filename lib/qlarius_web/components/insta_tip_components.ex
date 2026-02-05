defmodule QlariusWeb.InstaTipComponents do
  use QlariusWeb, :html

  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Money, only: [format_usd: 1]

  @default_amounts ["0.25", "0.50", "1.00", "2.00"]

  attr :recipient, :map, required: true
  attr :wallet_balance, :any, required: true
  attr :amounts, :list, default: @default_amounts
  attr :show_image, :boolean, default: true
  attr :show_message, :boolean, default: true
  attr :compact, :boolean, default: false
  attr :target, :any, default: nil
  attr :add_class, :string, default: nil

  def insta_tip_card(assigns) do
    ~H"""
    <div data-theme="light" class={["flex flex-col items-center", @add_class]}>
      <%!-- Recipient title --%>
      <%= if @recipient && (@show_image || @show_message) do %>
        <div class="text-xl font-bold text-base-content text-center mt-4 mb-2">
          {@recipient.name || "Recipient"}
        </div>
      <% end %>

      <%!-- Image and message - responsive layout --%>
      <%= if (@show_image || @show_message) && @recipient do %>
        <div class="flex flex-col md:!flex-row md:items-start items-center gap-4 w-full max-w-md px-4">
          <%= if @show_image do %>
            <div class="w-28 h-auto flex-shrink-0 bg-base-300 shadow-md flex items-center justify-center overflow-hidden rounded">
              <img
                src={
                  if @recipient.graphic_url do
                    QlariusWeb.Uploaders.RecipientBrandImage.url({@recipient.graphic_url, @recipient})
                  else
                    ~p"/images/tipjar_love_default.png"
                  end
                }
                alt={@recipient.name || "Recipient"}
                class="object-contain w-full h-full"
              />
            </div>
          <% end %>

          <%= if @show_message do %>
            <div class="text-base-content/70 text-base text-center md:!text-left flex-1">
              {@recipient.message ||
                "Thank you for supporting this content. Your Sponster tips are greatly appreciated!"}
            </div>
          <% end %>
        </div>

        <div class="divider my-4 w-full max-w-sm mx-auto" />
      <% end %>

      <div class={[
        "text-md mb-5 font-bold text-base-content text-center",
        if(!@show_image && !@show_message, do: "mt-4")
      ]}>
        Select an amount to InstaTip
      </div>

      <.insta_tip_button_group
        amounts={@amounts}
        wallet_balance={@wallet_balance}
        recipient_id={@recipient && @recipient.id}
        target={@target}
        add_class="mb-4"
      />

      <.insta_tip_footer wallet_balance={@wallet_balance} />
    </div>
    """
  end

  attr :wallet_balance, :any, required: true
  attr :add_class, :string, default: nil

  def insta_tip_footer(assigns) do
    ~H"""
    <div class={["flex-1 flex flex-col items-center mt-0", @add_class]}>
      <div class="text-base-content/70 text-sm mt-3 mb-4">
        From your wallet <.icon name="hero-arrow-right" class="w-4 h-4 inline-block" />
        <span class="inline-flex items-center w-auto text-lg bg-sponster-200 text-base-content px-3 py-1 rounded-lg border border-sponster-300">
          <span class="font-bold">{format_usd(@wallet_balance)}</span>
        </span>
      </div>
    </div>
    """
  end

  @doc "Deprecated: use insta_tip_footer instead"
  attr :wallet_balance, :any, required: true
  attr :add_class, :string, default: nil

  def insta_tip_header(assigns) do
    ~H"""
    <div class={["flex-1 flex flex-col items-center md:items-start mt-0", @add_class]}>
      <div class="text-base-content/70 text-sm mt-3 mb-4">
        From your wallet <.icon name="hero-arrow-right" class="w-4 h-4 inline-block" />
        <.wallet_balance id="wallet-balance-instatip-header" balance={@wallet_balance} />
      </div>
    </div>
    """
  end

  attr :amounts, :list, required: true
  attr :wallet_balance, :any, required: true
  attr :target, :any, default: nil
  attr :add_class, :string, default: nil
  attr :recipient_id, :integer, default: nil

  def insta_tip_button_group(assigns) do
    ~H"""
    <div class={["grid grid-cols-2 sm:grid-cols-4 gap-3 justify-items-center", @add_class]}>
      <%= for amount <- @amounts do %>
        <% amount_decimal = Decimal.new(amount)
        enabled = Decimal.compare(@wallet_balance, amount_decimal) != :lt %>
        <button
          type="button"
          phx-click="initiate_insta_tip"
          phx-target={@target}
          phx-value-amount={amount}
          phx-value-recipient-id={@recipient_id}
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
  attr :recipient_id, :integer, default: nil
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
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 text-base-content px-3 py-1 rounded-lg border border-sponster-300">
              <span class="font-bold">{format_usd(@current_balance)}</span>
            </span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-base-content/70">After Tip:</span>
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 text-base-content/60 px-3 py-1 ml-3 rounded-lg border border-dashed border-sponster-500">
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
            phx-value-recipient-id={@recipient_id}
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
