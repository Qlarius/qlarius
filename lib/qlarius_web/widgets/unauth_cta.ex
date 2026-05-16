defmodule QlariusWeb.Widgets.UnauthCTA do
  @moduledoc """
  Shared unauthenticated-viewer components and helpers for all widgets.

  ## Pattern

  Widgets (arqade, sponster tipjar, etc.) render the same page/content
  for anonymous viewers and authenticated viewers. The differences are
  isolated to two surfaces:

    * **Personal state** (wallet balance, offered amount, ads_count,
      tiqit-up credits, "has valid tiqit" badges): displayed with
      dashed placeholders (`$--.--` / `--`) when no user is present,
      so the layout is pixel-identical but unambiguous.

    * **Action controls** (Buy, InstaTip, Select tiqit class, Top up):
      either visually disabled, or clickable but intercepted by
      `select-*` event handlers that assign
      `show_connect_modal: true` instead of opening the real confirm/
      purchase modal.

  The `connect_wallet_modal/1` component is the single CTA surface
  across all widgets. Its primary action is the same
  `wallet_strip_or_connect/1` strip (READY + Connect) as elsewhere.
  It has two rendering modes for the Connect control:

    * **In-place AuthSheet mode** (preferred) — when the caller
      passes `on_click={JS.push("open_auth_sheet")}` (or similar),
      the CTA fires a `phx-click` that the hosting LiveView handles
      to open its embedded `AuthSheet` modal. No redirect, no iframe
      break-out.
    * **Legacy redirect mode** (fallback) — when `on_click` is `nil`,
      the CTA renders a `<.link href={interact_login_url()} target="_top">`
      that breaks out of iframes and lands on the main login page.
      Used on surfaces that don't host an `AuthSheet` yet (e.g.
      third-party iframe embeds, anon-share hosts).

  ## Where to use

    * `authed?/1` — cheap predicate over a `%Scope{}` or `nil`, usable
      in render branches and event-handler guards.
    * `format_usd_or_dashes/1` / `format_count_or_dashes/1` — drop-in
      replacements for `format_usd/1` when the value is personal.
    * `wallet_strip_or_connect/1` — drop-in replacement for the
      arqade `wallet_strip/1`; renders the authed strip when a scope
      is present, or the same two-column strip with **READY** (border strobe +
      subtle throb) and **WALLET** crossfading with strobing ellipsis in the pill
      footer + **Connect** (widget border strobe) when anonymous.
    * `connect_wallet_modal/1` — single-modal component; widgets
      toggle it via their existing `show_*_modal` assign pattern.

  ## LiveComponent-readiness

  None of these helpers read from global state. They take everything
  they need as attrs or arguments. When we later refactor
  `ArcadeLive` into a LiveComponent, these continue to work
  unchanged inside the LC's render.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Qlarius.Accounts.Scope
  alias Qlarius.Qlink.Urls

  import QlariusWeb.CoreComponents
  import QlariusWeb.Money
  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]

  @doc """
  True when `scope` represents a logged-in user we can transact on
  behalf of. Treats both `nil` scope and `%Scope{user: nil}` as
  unauthenticated.
  """
  @spec authed?(term()) :: boolean()
  def authed?(%Scope{user: %{id: _}}), do: true
  def authed?(_), do: false

  @doc """
  Formats a USD amount. Returns `$--.--` when the value is unknown
  (i.e. `nil` — typically because there's no current user). Always
  uses the same 2-decimal format as `format_usd/1` so the layout
  doesn't shift between states.
  """
  @spec format_usd_or_dashes(term()) :: String.t()
  def format_usd_or_dashes(nil), do: "$--.--"
  def format_usd_or_dashes(amount), do: format_usd(amount)

  @doc """
  Formats an integer count, returning `--` when `nil`. Mirrors
  `format_usd_or_dashes/1` for non-monetary counters (ads_count, etc.).
  """
  @spec format_count_or_dashes(term()) :: String.t()
  def format_count_or_dashes(nil), do: "--"
  def format_count_or_dashes(n) when is_integer(n), do: Integer.to_string(n)

  @doc """
  Wallet strip that renders the authed `wallet_strip/1` when a user is
  present, or the same two-column layout when anonymous: **READY** + WALLET
  label (instead of a dollar amount) and a **Connect** button (instead of
  **top-up**). The READY `wallet_balance` pill uses `anon_strobe?` for a Sponster
  border strobe (same tempo as Connect), a subtle READY throb, and a WALLET ↔
  ellipsis crossfade in the footer label row.
  **Connect** uses the same Sponster styling as the wallet pill (`btn-wallet-strip-action`)
  plus border + scale + subtle bg strobe (`connect-strip-cta-border-strobe`).

  Accepts an `id` prefix so the component is usable more than once
  on a page (each arqade LC/widget can namespace independently).

  Set `tray?={false}` to omit the outer base-200 tray (e.g. Sponster announcer bar).
  """
  attr :scope, :any, required: true, doc: "a %Scope{} or nil"
  attr :balance, :any, default: nil
  attr :offered_amount, :any, default: nil
  attr :ads_count, :any, default: nil
  attr :id, :string, default: "wallet-strip"
  attr :daily_gift_available?, :boolean, default: true

  attr :tray?, :boolean,
    default: true,
    doc: "When false, only the READY row + Connect (no outer tray)."

  attr :on_click, JS,
    default: nil,
    doc:
      "When set, the Connect CTA becomes a phx-click button that fires this JS command " <>
        "(typically `JS.push(\"open_auth_sheet\")` so the hosting LV opens its AuthSheet in " <>
        "place). When nil, falls back to a link."

  attr :connect_href, :string,
    default: nil,
    doc:
      "When `on_click` is nil and this is set, Connect uses this href. When both are nil, " <>
        "falls back to `interact_login_url/0`."

  attr :connect_link_target, :string,
    default: "_top",
    doc:
      "Target for the Connect `<.link>` when `on_click` is nil (e.g. `\"_self\"` for in-app login)."

  def wallet_strip_or_connect(assigns) do
    ~H"""
    <%= if authed?(@scope) do %>
      <QlariusWeb.Widgets.Arcade.Components.wallet_strip
        id={@id}
        balance={@balance}
        offered_amount={@offered_amount}
        ads_count={@ads_count || 0}
        daily_gift_available?={@daily_gift_available?}
      />
    <% else %>
      <% connect_classes =
        [
          if(@tray?,
            do: "btn-wallet-strip-action btn-md leading-none",
            else: "btn-wallet-strip-action btn-sm leading-none min-h-8 h-8 px-3 py-0"
          ),
          "connect-strip-cta-border-strobe"
        ] %>
      <%= if @tray? do %>
        <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-2 py-1.5 rounded-xl border border-base-300 max-w-full min-w-0">
          <div class="flex flex-row flex-nowrap justify-between items-center gap-2 min-w-0">
            <.wallet_balance
              id={@id}
              balance={Decimal.new("0")}
              footer_label="WALLET"
              value_text="READY"
              anon_strobe?={true}
            />
            <%= if @on_click do %>
              <button type="button" phx-click={@on_click} class={connect_classes}>
                <.connect_strip_cta_label />
              </button>
            <% else %>
              <% href =
                if @connect_href not in [nil, ""],
                  do: @connect_href,
                  else: Urls.interact_login_url() %>
              <.link href={href} target={@connect_link_target} class={connect_classes}>
                <.connect_strip_cta_label />
              </.link>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="flex flex-row flex-nowrap items-center justify-center gap-1.5 min-w-0 shrink">
          <.wallet_balance
            id={@id}
            balance={Decimal.new("0")}
            footer_label="WALLET"
            value_text="READY"
            anon_strobe?={true}
            compact?={true}
          />
          <%= if @on_click do %>
            <button type="button" phx-click={@on_click} class={connect_classes}>
              <.connect_strip_cta_label text_sm?={true} />
            </button>
          <% else %>
            <% href =
              if @connect_href not in [nil, ""],
                do: @connect_href,
                else: Urls.interact_login_url() %>
            <.link href={href} target={@connect_link_target} class={connect_classes}>
              <.connect_strip_cta_label text_sm?={true} />
            </.link>
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc false
  attr :text_sm?, :boolean, default: false

  def connect_strip_cta_label(assigns) do
    ~H"""
    <.icon
      name="hero-arrow-left"
      class={["shrink-0", if(@text_sm?, do: "w-3.5 h-3.5", else: "w-4 h-4")]}
    />
    <span class={["font-bold whitespace-nowrap", @text_sm? && "text-sm"]}>
      Connect
    </span>
    """
  end

  @doc """
  Standalone modal shown when an anonymous viewer attempts an action
  (e.g. tapping a tiqit class chip, the Buy button, Insta-Tip, etc).
  Widgets toggle this via a boolean assign (`:show_connect_modal`)
  and close it via a `phx-click` that assigns `false`.

  `on_cancel` defaults to a `JS.push("close-connect-modal")` so
  widgets can handle it via a uniform event name.

  Pass `connect_brand` to match `AuthSheet` header branding: `:tiqit` for Arqade,
  `:sponster` for Tips / Sponster surfaces, `:qadabra` for the neutral full
  wordmark. Omit `title` / `message` to use defaults tailored to the brand.
  """
  attr :show, :boolean, default: false
  attr :id, :string, default: "connect-wallet-modal"

  attr :title, :string,
    default: nil,
    doc: "Optional override; when nil, a default title is used (same for all brands today)."

  attr :message, :string,
    default: nil,
    doc: "Optional override; when nil, copy is chosen from `connect_brand`."

  attr :connect_brand, :any,
    default: nil,
    doc:
      "`:tiqit` (Arqade), `:sponster` (Tips), or `:qadabra`; controls header logo and default body copy."

  attr :on_cancel, JS, default: JS.push("close-connect-modal")

  attr :on_click, JS,
    default: nil,
    doc:
      "When set, the primary CTA becomes a phx-click button firing this JS command (to open " <>
        "the hosting LV's AuthSheet). When nil, falls back to the legacy redirect link."

  attr :scope, :any,
    default: nil,
    doc:
      "Optional `%Scope{}`; defaults to anon. Used by the embedded `wallet_strip_or_connect/1`."

  attr :wallet_strip_id, :string,
    default: nil,
    doc: "Dom id prefix for the strip's balance node (defaults to `id <> \"-wallet-strip\"`)."

  def connect_wallet_modal(assigns) do
    brand = normalize_connect_modal_brand(Map.get(assigns, :connect_brand))

    title =
      case Map.get(assigns, :title) do
        t when is_binary(t) ->
          t = String.trim(t)
          if t != "", do: t, else: default_connect_modal_title(brand)

        _ ->
          default_connect_modal_title(brand)
      end

    message =
      case Map.get(assigns, :message) do
        m when is_binary(m) ->
          m = String.trim(m)
          if m != "", do: m, else: default_connect_modal_message(brand)

        _ ->
          default_connect_modal_message(brand)
      end

    assigns =
      assigns
      |> assign(:connect_brand, brand)
      |> assign(:header_logo, connect_modal_brand_logo(brand))
      |> assign(:title, title)
      |> assign(:message, message)

    ~H"""
    <.modal :if={@show} id={@id} on_cancel={@on_cancel} show>
      <div class="flex flex-col items-center text-center space-y-4 p-8">
        <div class="mb-4 md:mb-5">
          <img
            src={@header_logo.src}
            alt={@header_logo.alt}
            class={@header_logo.class}
          />
        </div>
        <h2 class="text-xl font-bold text-base-content">{@title}</h2>
        <p class="text-base-content/70 max-w-sm">{@message}</p>
        <div class="w-full max-w-md flex justify-center">
          <.wallet_strip_or_connect
            scope={@scope}
            balance={Decimal.new("0")}
            id={@wallet_strip_id || "#{@id}-wallet-strip"}
            on_click={@on_click}
          />
        </div>
        <p class="text-xs text-base-content/65 leading-snug max-w-sm">
          Your US mobile number is all you need. New wallets are even prefunded with $3.00+ on us.
        </p>
        <button
          type="button"
          phx-click={@on_cancel}
          class="text-sm text-base-content/50 hover:text-base-content underline-offset-2 hover:underline"
        >
          Keep browsing
        </button>
      </div>
    </.modal>
    """
  end

  defp normalize_connect_modal_brand(nil), do: :qadabra

  defp normalize_connect_modal_brand(b) when b in [:qadabra, :sponster, :tiqit], do: b

  defp normalize_connect_modal_brand(b) when is_binary(b) do
    case String.downcase(String.trim(b)) do
      "sponster" -> :sponster
      "tiqit" -> :tiqit
      "qadabra" -> :qadabra
      _ -> :qadabra
    end
  end

  defp normalize_connect_modal_brand(_), do: :qadabra

  defp connect_modal_brand_logo(:sponster) do
    %{
      src: "/images/Sponster_logo_color_horiz.svg",
      alt: "Sponster",
      class: "h-9 w-auto max-w-[min(18rem,88vw)] object-contain md:h-11"
    }
  end

  defp connect_modal_brand_logo(:tiqit) do
    %{
      src: "/images/Tiqit_logo_color_horiz.svg",
      alt: "Tiqit",
      class: "h-9 w-auto max-w-[min(18rem,88vw)] object-contain md:h-11"
    }
  end

  defp connect_modal_brand_logo(_) do
    %{
      src: "/images/qadabra_full_gray_opt.svg",
      alt: "Qadabra",
      class: "h-10 w-auto max-w-[min(20rem,88vw)] object-contain md:h-11"
    }
  end

  defp default_connect_modal_title(_brand), do: "Connect to continue"

  defp default_connect_modal_message(:tiqit) do
    "Once connected, you will have full access to purchase tiqits to your favorite media."
  end

  defp default_connect_modal_message(:sponster) do
    "Once connected, you will have full access to fund your wallet, collect revenues from ads, and support your favorite creators and media."
  end

  defp default_connect_modal_message(_) do
    "Once connected, you will have full access to your Qadabrawallet, tiqits, ads, and all other features."
  end
end
