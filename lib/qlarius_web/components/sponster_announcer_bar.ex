defmodule QlariusWeb.Components.SponsterAnnouncerBar do
  @moduledoc """
  Fixed bottom Sponster announcer bar shared by Qlink and public Tiqit Arqade pages.

  Authed viewers see a compact wallet pill; anonymous viewers see READY + Connect.
  Theme (light/dark) inherits from the nearest `[data-theme]` ancestor — typically
  `<html>` — via shared `wallet-balance-pill` / `btn-wallet-strip-action` styles.
  """
  use Phoenix.Component

  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.Widgets.UnauthCTA, only: [authed?: 1, wallet_strip_or_connect: 1]

  attr :id_prefix, :string, default: "sponster"
  attr :current_scope, :map, default: nil
  attr :show_sponster_drawer, :boolean, default: false
  attr :on_auth_click, Phoenix.LiveView.JS, default: nil
  attr :connect_href, :string, default: nil
  attr :connect_link_target, :string, default: "_self"
  attr :toggle_event, :string, default: "toggle_sponster_drawer"

  def sponster_announcer_bar(assigns) do
    authed = authed?(assigns.current_scope)

    assigns =
      assigns
      |> assign(:authed, authed)
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
      class="fixed inset-x-0 bottom-0 flex justify-center bg-base-100 shadow-[0_-4px_16px_rgba(0,0,0,0.06)] isolate"
      style="z-index: 63;"
    >
      <div class="flex h-[50px] w-full max-w-3xl items-center justify-between gap-2 px-3">
        <div class="sponster-announcer-logo-container shrink-0 md:relative md:z-10" />
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
            <span class="shrink-0 font-bold whitespace-nowrap tabular-amount">
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
