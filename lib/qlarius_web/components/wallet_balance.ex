defmodule QlariusWeb.Components.WalletBalance do
  @moduledoc """
  Wallet amount pill used in headers, strips, and embeds.

  Lives in its own module so `AdsComponents` can import it without creating a
  compile-time cycle with `CustomComponentsMobile` (`use QlariusWeb, :html`
  pulls in `AdsComponents`).
  """
  use Phoenix.Component

  import QlariusWeb.Money

  attr :balance, :any, required: true
  attr :id, :string, default: "wallet-balance"
  attr :footer_label, :string, default: nil
  attr :value_text, :string, default: nil

  attr :anon_strobe?, :boolean,
    default: false,
    doc:
      "When true (e.g. anon wallet strip), applies `wallet-strip-anon-focus`: Sponster border strobe " <>
        "in sync with Connect CTA tempo. With `value_text`, READY gets a subtle scale throb; with " <>
        "`footer_label` as well, the footer label (e.g. WALLET) crossfades with strobing ellipsis."

  attr :compact?, :boolean, default: false

  attr :icon?, :boolean,
    default: true,
    doc: "Labelled pills show a wallet icon; false drops it (e.g. confirmation dialogs)."

  # With `footer_label` (widgets, the Sponster bar and drawer) the pill is
  # labelled: a wallet icon beside the amount in tabular figures, and the label
  # ("WALLET") becomes the accessible name. Without it (app headers) it is the
  # plain amount chip. WalletPulse reads `innerText` for the amount, so the
  # label stays out of the text.
  def wallet_balance(assigns) do
    assigns = assign(assigns, :labelled?, assigns.footer_label not in [nil, ""])

    ~H"""
    <span
      id={@id}
      phx-hook="WalletPulse"
      data-wallet-balance={balance_string(@balance)}
      role={@labelled? && "group"}
      aria-label={@labelled? && String.capitalize(@footer_label)}
      title={@labelled? && String.capitalize(@footer_label)}
      class={[
        "wallet-balance-pill",
        if(@compact?, do: "wallet-balance-pill--compact", else: "wallet-balance-pill--default"),
        @labelled? && "wallet-balance-pill--labelled",
        if(@anon_strobe?, do: "wallet-strip-anon-focus")
      ]}
    >
      <span
        :if={@labelled? && @icon?}
        class="hero-wallet wallet-balance-pill__icon"
        aria-hidden="true"
      />
      <span class="font-bold leading-tight inline-flex flex-wrap items-center justify-center gap-0">
        <%= if @value_text not in [nil, ""] do %>
          <%= if @anon_strobe? do %>
            <span class="wallet-ready-throb whitespace-nowrap">
              {String.trim_trailing(@value_text, ".")}
            </span>
          <% else %>
            {@value_text}
          <% end %>
        <% else %>
          {format_usd(@balance)}
        <% end %>
      </span>
    </span>
    """
  end

  defp balance_string(%Decimal{} = balance), do: Decimal.to_string(balance)
  defp balance_string(balance) when is_binary(balance), do: balance
  defp balance_string(_), do: "0"
end
