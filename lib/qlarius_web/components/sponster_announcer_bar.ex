defmodule QlariusWeb.Components.SponsterAnnouncerBar do
  @moduledoc """
  Fixed bottom Sponster announcer bar shared by Qlink pages, public Tiqit
  Arqade pages, and the third-party embed widget.

  Authed viewers see a compact wallet pill. Anonymous viewers see either:

    * `anon_display: :connect` (default) — READY + Connect strip, or
    * `anon_display: :promo` — rotating promotional banners (up to 80px tall,
      bottom-justified so they overflow ~30px above the 50px bar) plus a
      spinning coin that bounces behind the bar and peeks above it. Used by
      the third-party embed ("recruiter mode"). While the drawer is open the
      promo yields to the READY + Connect strip so engaged visitors always
      have a connect affordance.

  Theme (light/dark) inherits from the nearest `[data-theme]` ancestor — typically
  `<html>` — via shared `wallet-balance-pill` / `btn-wallet-strip-action` styles.
  """
  use Phoenix.Component

  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.Widgets.UnauthCTA, only: [authed?: 1, wallet_strip_or_connect: 1]

  @default_promo_slides [
    "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/DontReadThis_640.png",
    "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/LifeSponsored_640.png",
    "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/SellYourAttention_640.png"
  ]

  attr :id_prefix, :string, default: "sponster"
  attr :current_scope, :map, default: nil
  attr :show_sponster_drawer, :boolean, default: false
  attr :on_auth_click, Phoenix.LiveView.JS, default: nil
  attr :connect_href, :string, default: nil
  attr :connect_link_target, :string, default: "_self"
  attr :toggle_event, :string, default: "toggle_sponster_drawer"

  attr :anon_display, :atom,
    default: :connect,
    values: [:connect, :promo],
    doc: "Anonymous-viewer center content: READY+Connect strip or rotating promo banners."

  attr :promo_slides, :list,
    default: @default_promo_slides,
    doc: "Banner image URLs for the :promo anon display (single set, all screen sizes)."

  def sponster_announcer_bar(assigns) do
    authed = authed?(assigns.current_scope)
    promo? = !authed && assigns.anon_display == :promo && !assigns.show_sponster_drawer

    assigns =
      assigns
      |> assign(:authed, authed)
      |> assign(:promo?, promo?)
      |> assign(:ads_count, if(authed, do: to_string(assigns.current_scope.ads_count || 0), else: ""))
      |> assign(
        :offered,
        if(authed,
          do: format_usd(assigns.current_scope.offered_amount || Decimal.new("0")),
          else: ""
        )
      )

    ~H"""
    <div
      class="sponster-announcer-bar fixed inset-x-0 bottom-0 flex justify-center isolate"
      style="z-index: 63;"
    >
      <%!-- Coin bounce layer (promo only): 80px tall, clipped, painted behind
           the bar surface so the coin hides behind the bar and peeks above it. --%>
      <%= if @promo? do %>
        <div class="sponster-announcer-coin-layer" aria-hidden="true">
          <div class="spin-bounce-background-item">
            <div class="spinner">
              <img src="/images/sponster_us_quarter.png" alt="" />
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Bar surface: 50px background/shadow strip. Kept separate from the
           content row so promo banners + coin can overflow above it. --%>
      <div class="sponster-announcer-bar__surface absolute inset-x-0 bottom-0 z-10 h-[50px] bg-base-100 shadow-[0_-4px_16px_rgba(0,0,0,0.06)]" />

      <div class="relative z-20 flex h-[50px] w-full max-w-3xl items-center justify-between gap-2 px-3">
        <div class="sponster-announcer-logo-container shrink-0 md:relative md:z-10" />
        <%= if @promo? do %>
          <%!-- Rotating promo banners: 80px tall, bottom-justified flush with
               the bar bottom, overflowing ~30px above the 50px bar. --%>
          <div class="relative h-[50px] flex-1 min-w-0 px-1">
            <div
              id={"#{@id_prefix}-announcer-promo-carousel"}
              phx-hook="Carousel"
              phx-update="ignore"
              data-autoplay-interval="4000"
              class="absolute inset-x-0 bottom-0 h-[80px] overflow-hidden"
            >
              <%= for slide <- @promo_slides do %>
                <div class="absolute inset-0 transition-opacity duration-1000 opacity-0" data-slide>
                  <img
                    class="absolute inset-0 h-full w-full object-contain object-bottom"
                    src={slide}
                    alt="Sponster promotion"
                  />
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="flex flex-1 justify-center min-w-0 px-1 md:absolute md:left-1/2 md:top-1/2 md:z-0 md:w-max md:max-w-[min(70%,22rem)] md:-translate-x-1/2 md:-translate-y-1/2 md:px-2">
            <%= if @authed do %>
              <.wallet_balance
                id={"#{@id_prefix}-announcer-wallet-balance"}
                balance={@current_scope.wallet_balance || Decimal.new("0")}
                footer_label="WALLET"
                compact?={true}
              />
            <% else %>
              <div title="Connect your wallet">
                <.wallet_strip_or_connect
                  tray?={false}
                  scope={@current_scope}
                  balance={Decimal.new("0")}
                  id={"#{@id_prefix}-announcer-wallet-strip"}
                  on_click={@on_auth_click}
                  connect_href={@connect_href}
                  connect_link_target={@connect_link_target}
                />
              </div>
            <% end %>
          </div>
        <% end %>
        <button
          type="button"
          id={"#{@id_prefix}-sponster-drawer-toggle"}
          phx-click={@toggle_event}
          title={if @show_sponster_drawer, do: "Hide offers", else: "Show offers"}
          class={[
            "qlink-sponster-drawer-toggle btn-widget btn-widget-emphasis btn-md rounded-full leading-none border-[1.5px]",
            "inline-flex shrink-0 cursor-pointer items-center justify-center gap-2 transition-colors md:relative md:z-10",
            "outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/40"
          ]}
        >
          <%= if @authed do %>
            <span class="shrink-0 font-bold whitespace-nowrap">
              {@ads_count} ads • {@offered}
            </span>
          <% else %>
            <span class="text-sm font-bold whitespace-nowrap">
              {if @show_sponster_drawer, do: "Hide", else: "Info"}
            </span>
          <% end %>
          <span class={[
            "hero-chevron-double-up all-animate bg-sponster-600 shrink-0",
            if(@show_sponster_drawer, do: "rotate-180")
          ]} />
        </button>
      </div>
    </div>
    """
  end
end
