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
  across all widgets — one visual, one link, one destination
  (`Qlarius.Qlink.Urls.interact_login_url/0` with `target="_top"` so
  the iframe breaks out).

  ## Where to use

    * `authed?/1` — cheap predicate over a `%Scope{}` or `nil`, usable
      in render branches and event-handler guards.
    * `format_usd_or_dashes/1` / `format_count_or_dashes/1` — drop-in
      replacements for `format_usd/1` when the value is personal.
    * `wallet_strip_or_connect/1` — drop-in replacement for the
      arqade `wallet_strip/1`; renders the authed strip when a scope
      is present, a Connect CTA otherwise.
    * `connect_wallet_modal/1` — single-modal component; widgets
      toggle it via their existing `show_*_modal` assign pattern.
    * `connect_wallet_link/1` — the same CTA in inline-link form
      (used anywhere the modal would be overkill, e.g. the center
      buy/play column of the arqade).

  ## LiveComponent-readiness

  None of these helpers read from global state. They take everything
  they need as attrs or arguments. When we later refactor
  `ArcadeLive` into a LiveComponent, these continue to work
  unchanged inside the LC's render.
  """

  use Phoenix.Component

  alias Qlarius.Accounts.Scope
  alias Qlarius.Qlink.Urls

  import QlariusWeb.CoreComponents
  import QlariusWeb.Money

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
  present, or a Connect-wallet alternate layout otherwise. The anon
  layout uses the same outer pill styling + same pixel footprint so
  switching between states doesn't jitter the page.

  Accepts an `id` prefix so the component is usable more than once
  on a page (each arqade LC/widget can namespace independently).
  """
  attr :scope, :any, required: true, doc: "a %Scope{} or nil"
  attr :balance, :any, default: nil
  attr :offered_amount, :any, default: nil
  attr :ads_count, :any, default: nil
  attr :id, :string, default: "wallet-strip"

  def wallet_strip_or_connect(assigns) do
    ~H"""
    <%= if authed?(@scope) do %>
      <QlariusWeb.Widgets.Arcade.Components.wallet_strip
        id={@id}
        balance={@balance}
        offered_amount={@offered_amount}
        ads_count={@ads_count || 0}
      />
    <% else %>
      <div class="w-fit mx-auto text-base-content bg-base-200 border-t border-base-300 px-3 py-2 rounded-lg border-1 border-base-300">
        <div class="flex flex-row flex-wrap justify-between items-center space-x-4">
          <div class="flex flex-row items-center justify-center">
            <span
              id={@id}
              class="inline-flex items-center w-auto text-lg bg-sponster-200 dark:bg-sponster-800 text-base-content/60 px-3 py-1 rounded-lg border border-sponster-300 dark:border-sponster-500"
            >
              <span class="font-bold">{format_usd_or_dashes(nil)}</span>
            </span>
            <span class="font-normal text-base-content/60 ml-2 mr-3">to spend</span>
          </div>

          <.link
            href={Urls.interact_login_url()}
            target="_top"
            class="btn btn-md rounded-full !bg-sponster-400 hover:!bg-sponster-600 text-white !border-sponster-400 hover:!border-sponster-600 leading-none"
          >
            <.icon name="hero-wallet" class="w-4 h-4 mr-1" />
            <span class="font-bold">Connect wallet</span>
          </.link>
        </div>
      </div>
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

  attr :on_cancel, Phoenix.LiveView.JS,
    default: Phoenix.LiveView.JS.push("close-connect-modal")

  def connect_wallet_modal(assigns) do
    ~H"""
    <.modal :if={@show} id={@id} on_cancel={@on_cancel} show>
      <div class="flex flex-col items-center text-center space-y-4 p-8">
        <div class="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
          <.icon name="hero-wallet" class="w-8 h-8 text-primary" />
        </div>
        <h2 class="text-xl font-bold text-base-content">{@title}</h2>
        <p class="text-base-content/70 max-w-sm">{@message}</p>
        <.link
          href={Urls.interact_login_url()}
          target="_top"
          class="btn btn-primary btn-lg btn-block rounded-full"
        >
          <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 mr-2" />
          Connect your wallet
        </.link>
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

  @doc """
  Inline Connect-wallet link. Use where a full modal is overkill
  (e.g. the center Buy/Play column of a piece-detail layout).
  Styled to occupy the same visual footprint as the primary action
  button it replaces.
  """
  attr :class, :string, default: "btn btn-primary btn-lg btn-block rounded-full"
  attr :label, :string, default: "Connect your wallet"
  attr :subtext, :string, default: nil
  attr :rest, :global

  def connect_wallet_link(assigns) do
    ~H"""
    <.link href={Urls.interact_login_url()} target="_top" class={@class} {@rest}>
      <.icon name="hero-wallet" class="h-5 w-5 mr-2" /> {@label}
    </.link>
    <p :if={@subtext} class="text-xs text-base-content/60">{@subtext}</p>
    """
  end
end
