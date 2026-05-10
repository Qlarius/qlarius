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
      is present, or the same two-column strip with **READY** + **Connect**
      (Sponster ring strobe on the READY pill) when anonymous.
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
  top-up). The READY `wallet_balance` pill uses `anon_strobe?` for a subtle
  Sponster fill pulse.

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
  attr :tray?, :boolean, default: true, doc: "When false, only the READY row + Connect (no outer tray)."

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
    doc: "Target for the Connect `<.link>` when `on_click` is nil (e.g. `\"_self\"` for in-app login)."

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
           if @tray?,
             do: "btn-widget btn-md rounded-full leading-none",
             else: "btn-widget btn-sm rounded-full leading-none min-h-8 h-8 px-3 py-0" %>
      <%= if @tray? do %>
        <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-2 py-1.5 rounded-xl border border-base-300 max-w-full min-w-0">
          <div class="flex flex-row flex-nowrap justify-between items-center gap-2 min-w-0">
            <.wallet_balance
              id={@id}
              balance={Decimal.new("0")}
              footer_label="WALLET"
              value_text="READY"
              anon_strobe?={true}
              anon_ready_ellipsis?={true}
            />
            <%= if @on_click do %>
              <button type="button" phx-click={@on_click} class={connect_classes}>
                <span class="font-bold">Connect</span>
              </button>
            <% else %>
              <% href =
                   if @connect_href not in [nil, ""],
                     do: @connect_href,
                     else: Urls.interact_login_url() %>
              <.link href={href} target={@connect_link_target} class={connect_classes}>
                <span class="font-bold">Connect</span>
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
            anon_ready_ellipsis?={true}
            compact?={true}
          />
          <%= if @on_click do %>
            <button type="button" phx-click={@on_click} class={connect_classes}>
              <span class="font-bold text-sm">Connect</span>
            </button>
          <% else %>
            <% href =
                 if @connect_href not in [nil, ""],
                   do: @connect_href,
                   else: Urls.interact_login_url() %>
            <.link href={href} target={@connect_link_target} class={connect_classes}>
              <span class="font-bold text-sm">Connect</span>
            </.link>
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Standalone modal shown when an anonymous viewer attempts an action
  (e.g. tapping a tiqit class chip, the Buy button, Insta-Tip, etc).
  Widgets toggle this via a boolean assign (`:show_connect_modal`)
  and close it via a `phx-click` that assigns `false`.

  `on_cancel` defaults to a `JS.push("close-connect-modal")` so
  widgets can handle it via a uniform event name.
  """
  attr :show, :boolean, default: false
  attr :id, :string, default: "connect-wallet-modal"
  attr :title, :string, default: "Connect your wallet to continue"

  attr :message, :string,
    default:
      "Sign in on Qadabra to buy Tiqits, tip creators, and earn from ads. Your wallet follows you across Qadabra."

  attr :on_cancel, JS, default: JS.push("close-connect-modal")

  attr :on_click, JS,
    default: nil,
    doc:
      "When set, the primary CTA becomes a phx-click button firing this JS command (to open " <>
        "the hosting LV's AuthSheet). When nil, falls back to the legacy redirect link."

  attr :scope, :any,
    default: nil,
    doc: "Optional `%Scope{}`; defaults to anon. Used by the embedded `wallet_strip_or_connect/1`."

  attr :wallet_strip_id, :string,
    default: nil,
    doc: "Dom id prefix for the strip's balance node (defaults to `id <> \"-wallet-strip\"`)."

  def connect_wallet_modal(assigns) do
    ~H"""
    <.modal :if={@show} id={@id} on_cancel={@on_cancel} show>
      <div class="flex flex-col items-center text-center space-y-4 p-8">
        <div class="w-16 h-16 rounded-full bg-widget-100 flex items-center justify-center">
          <.icon name="hero-wallet" class="w-8 h-8 text-widget-700" />
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
          Use your mobile number to connect. New wallets prefunded with $3.00+ on us.
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
end
