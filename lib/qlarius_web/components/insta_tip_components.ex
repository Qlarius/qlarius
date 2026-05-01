defmodule QlariusWeb.InstaTipComponents do
  use QlariusWeb, :html

  alias Phoenix.LiveView.JS
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.Widgets.UnauthCTA, only: [wallet_strip_or_connect: 1]

  @default_amounts ["0.25", "0.50", "1.00", "2.00"]

  # `scope` is the current `%Scope{}` (or nil for anonymous viewers).
  # Passed through to `wallet_strip_or_connect/1` so the wallet
  # footer renders the real balance + top-up popover for authed
  # viewers, or `$--.--` + a Connect-wallet button for anonymous
  # viewers — same visual component the arqade widget uses.
  #
  # `wallet_balance` is kept as an explicit attr so the scope can be
  # nil while still displaying a live-updated balance (e.g. after a
  # tip). Most callers should simply pass `@current_scope.wallet_balance`.
  attr :recipient, :map, required: true
  attr :scope, :any, default: nil
  attr :wallet_balance, :any, required: true
  attr :offered_amount, :any, default: nil
  attr :ads_count, :any, default: nil
  attr :amounts, :list, default: @default_amounts
  attr :show_image, :boolean, default: true
  attr :show_message, :boolean, default: true
  attr :compact, :boolean, default: false
  attr :target, :any, default: nil
  attr :add_class, :string, default: nil
  attr :wallet_strip_id, :string, default: "wallet-balance-tipjar"

  attr :on_auth_click, JS,
    default: nil,
    doc:
      "Passed through to the embedded `wallet_strip_or_connect/1` Connect-wallet CTA. When " <>
        "nil, the CTA keeps its legacy redirect behavior."

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

      <div class="mt-2 mb-4">
        <.wallet_strip_or_connect
          id={@wallet_strip_id}
          scope={@scope}
          balance={@wallet_balance}
          offered_amount={@offered_amount}
          ads_count={@ads_count}
          on_click={@on_auth_click}
        />
      </div>
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
            <div class="text-3xl font-bold text-sponster-600 dark:text-sponster-300 mb-2">
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
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content dark:text-sponster-100 px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500">
              <span class="font-bold">{format_usd(@current_balance)}</span>
            </span>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-base-content/70">After Tip:</span>
            <span class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content dark:text-sponster-100 px-3 py-1 ml-3 rounded-lg border border-dashed border-sponster-500 dark:border-sponster-400">
              <span class="font-bold text-base-content/90 dark:text-sponster-100/90">
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
            class="btn-widget flex-1 font-bold rounded-full"
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

  @doc """
  Thanks/confirmation modal shown after a successful InstaTip. Auto-dismisses
  after 3 seconds and has standard close button. Uses same styling as other modals.
  """
  attr :show, :boolean, default: false
  attr :recipient_name, :string, required: true
  attr :amount, :any, required: true

  def insta_tip_thanks_modal(assigns) do
    ~H"""
    <.modal :if={@show} id="insta-tip-thanks-modal" show on_cancel={JS.push("close-insta-tip-thanks-modal")}>
      <div class="text-center space-y-6 p-8">
        <div class="space-y-4">
          <div class="text-5xl mb-2">✓</div>
          <h2 class="text-xl font-bold text-success">Thank you!</h2>
          <p class="text-base-content">
            Your tip of <span class="font-bold text-sponster-600 dark:text-sponster-300">{format_usd(@amount)}</span>
            to <span class="font-semibold">{@recipient_name}</span> was sent.
          </p>
        </div>
        <button
          type="button"
          phx-click="close-insta-tip-thanks-modal"
          class="btn-widget rounded-full"
        >
          Done
        </button>
      </div>
    </.modal>
    """
  end
end
