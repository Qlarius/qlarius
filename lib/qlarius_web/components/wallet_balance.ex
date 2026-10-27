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
  #
  # A labelled pill with a real balance opens /wallet in a new tab. The link is
  # absolute on the public app host (qadabra.app) so it resolves when the pill
  # renders on qlinkin.bio or inside a publisher-embedded widget. The installed
  # app already has Wallet in the shell, so that link is inert there.
  def wallet_balance(assigns) do
    labelled? = assigns.footer_label not in [nil, ""]
    # READY and confirmation dialogs stay put. Dialogs drop the icon.
    open_wallet? = labelled? && assigns.icon? && assigns.value_text in [nil, ""]

    assigns =
      assigns
      |> assign(:labelled?, labelled?)
      |> assign(:open_wallet?, open_wallet?)
      |> assign(:wallet_href, Qlarius.Qlink.Urls.wallet_url())
      |> assign(:pill_class, pill_class(assigns, labelled?, open_wallet?))

    ~H"""
    <a
      :if={@open_wallet?}
      id={@id}
      href={@wallet_href}
      target="_blank"
      rel="noopener noreferrer"
      phx-hook="WalletPulse"
      data-wallet-balance={balance_string(@balance)}
      aria-label={String.capitalize(@footer_label)}
      title={String.capitalize(@footer_label)}
      class={@pill_class}
    >
      <.pill_face
        labelled?={@labelled?}
        icon?={@icon?}
        value_text={@value_text}
        anon_strobe?={@anon_strobe?}
        balance={@balance}
      />
    </a>
    <span
      :if={!@open_wallet?}
      id={@id}
      phx-hook="WalletPulse"
      data-wallet-balance={balance_string(@balance)}
      role={@labelled? && "group"}
      aria-label={@labelled? && String.capitalize(@footer_label)}
      title={@labelled? && String.capitalize(@footer_label)}
      class={@pill_class}
    >
      <.pill_face
        labelled?={@labelled?}
        icon?={@icon?}
        value_text={@value_text}
        anon_strobe?={@anon_strobe?}
        balance={@balance}
      />
    </span>
    """
  end

  attr :labelled?, :boolean, required: true
  attr :icon?, :boolean, required: true
  attr :value_text, :any, required: true
  attr :anon_strobe?, :boolean, required: true
  attr :balance, :any, required: true

  defp pill_face(assigns) do
    ~H"""
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
    """
  end

  defp pill_class(assigns, labelled?, open_wallet?) do
    [
      "wallet-balance-pill",
      if(assigns.compact?,
        do: "wallet-balance-pill--compact",
        else: "wallet-balance-pill--default"
      ),
      labelled? && "wallet-balance-pill--labelled",
      open_wallet? && "wallet-balance-pill--link",
      if(assigns.anon_strobe?, do: "wallet-strip-anon-focus")
    ]
  end

  defp balance_string(%Decimal{} = balance), do: Decimal.to_string(balance)
  defp balance_string(balance) when is_binary(balance), do: balance
  defp balance_string(_), do: "0"
end
