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
  attr :anon_strobe?, :boolean, default: false,
    doc:
      "When true (e.g. anon wallet strip), applies `wallet-strip-anon-focus`: Sponster border strobe " <>
        "in sync with Connect CTA tempo. With `value_text`, READY gets a subtle scale throb; with " <>
        "`footer_label` as well, the footer label (e.g. WALLET) crossfades with strobing ellipsis."
  attr :compact?, :boolean, default: false

  def wallet_balance(assigns) do
    ~H"""
    <span
      id={@id}
      phx-hook="WalletPulse"
      class={[
        "inline-flex w-auto bg-sponster-200 dark:bg-sponster-800 text-base-content dark:text-sponster-100 rounded-md border border-sponster-300 dark:border-sponster-500",
        if(@compact?, do: "px-2 py-0.5", else: "px-3 py-1.5"),
        if(@footer_label,
          do: [
            "flex-col items-center justify-center gap-0.5",
            if(@compact?, do: "text-base", else: "text-lg")
          ],
          else: [if(@compact?, do: "items-center text-base", else: "items-center text-lg")]
        ),
        if(@anon_strobe?, do: "wallet-strip-anon-focus")
      ]}
    >
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
      <%= if @footer_label not in [nil, ""] do %>
        <%= if @anon_strobe? && @value_text not in [nil, ""] do %>
          <span
            class="wallet-footer-label-dissolve-wrap text-base-content/40 font-medium"
            style="font-size: 8px; line-height: 10px; letter-spacing: 0.2px; margin-top: -4px;"
          >
            <span class="wallet-footer-label-dissolve-word">{@footer_label}</span>
            <span class="wallet-footer-label-dissolve-dots" aria-hidden="true">
              <span class="wallet-footer-ellipsis">
                <span class="wallet-footer-ellipsis-dot">.</span>
                <span class="wallet-footer-ellipsis-dot">.</span>
                <span class="wallet-footer-ellipsis-dot">.</span>
              </span>
            </span>
          </span>
        <% else %>
          <span
            class="text-base-content/40 font-medium"
            style="font-size: 8px; line-height: 10px; letter-spacing: 0.2px; margin-top: -4px;"
          >
            {@footer_label}
          </span>
        <% end %>
      <% end %>
    </span>
    """
  end
end
