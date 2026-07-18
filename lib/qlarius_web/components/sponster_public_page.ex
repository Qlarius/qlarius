defmodule QlariusWeb.Components.SponsterPublicPage do
  use Phoenix.Component

  import QlariusWeb.CoreComponents
  import QlariusWeb.Helpers.ImageHelpers, only: [recipient_brand_image_url: 2]
  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.SplitComponents
  import QlariusWeb.Components.SponsterAnnouncerBar
  import QlariusWeb.Components.CustomComponentsMobile, only: [wallet_balance: 1]
  import QlariusWeb.Widgets.UnauthCTA

  alias Qlarius.Qlink.Urls
  alias QlariusWeb.Helpers.SponsterInfoIframe

  attr :recipient, :map, required: true
  attr :creator, :map, default: nil
  attr :current_scope, :map, default: nil
  attr :tip_only, :boolean, default: false
  attr :show_sponster_drawer, :boolean, default: false
  attr :show_split_drawer, :boolean, default: false
  attr :show_split_reminder, :boolean, default: false
  attr :sponster_disclaimer_dock_visible, :boolean, default: false
  attr :loading_offers, :boolean, default: false
  attr :active_offers, :list, default: []
  attr :video_offers, :list, default: []
  attr :completed_video_offers, :list, default: []
  attr :selected_ad_type, :string, default: "three_tap"
  attr :show_ad_type_tabs, :boolean, default: false
  attr :host_uri, :any, default: nil
  attr :me_file_sponsorship_url, :string, default: nil
  attr :settings_notifications_url, :string, default: nil
  attr :user_ip, :string, default: "0.0.0.0"
  attr :auth_sheet_enabled?, :boolean, default: false
  attr :on_auth_click, Phoenix.LiveView.JS, default: nil
  attr :connect_href, :string, default: nil
  attr :connect_link_target, :string, default: "_self"
  attr :announcer_id_prefix, :string, default: "sponster"
  attr :split_panel_id, :string, default: "sponster-split-settings-panel"
  attr :info_context, :atom, default: :default

  attr :announcer_anon_display, :atom,
    default: :connect,
    values: [:connect, :promo],
    doc: "Anonymous announcer center content — see `sponster_announcer_bar/1`."

  def sponster_stack(assigns) do
    referral_code =
      case assigns.recipient do
        %{referral_code: code} when is_binary(code) -> code
        _ -> nil
      end

    assigns =
      assigns
      |> assign(:info_iframe_src, SponsterInfoIframe.src(assigns.info_context))
      |> assign(:sponster_info_outbound_url, Urls.sponster_info_outbound_url(referral_code))

    ~H"""
    <%= if @recipient do %>
      <div
        id={"#{@announcer_id_prefix}-drawer-backdrop"}
        phx-hook="BodyScrollLock"
        data-body-scroll-lock={if @show_sponster_drawer, do: "true", else: "false"}
        class={[
          "fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity duration-300",
          if(@show_sponster_drawer, do: "opacity-100", else: "opacity-0 pointer-events-none")
        ]}
        style="z-index: 61;"
        phx-click="close_sponster_drawer"
      >
      </div>

      <div
        class={[
          "fixed page-canvas rounded-t-lg overflow-hidden flex flex-col transition-all duration-300 ease-out",
          "h-[calc(95vh-50px)]",
          if(@show_sponster_drawer, do: "bottom-[50px]", else: "-bottom-[calc(95vh-50px)]")
        ]}
        style="z-index: 62; left: 50%; transform: translateX(-50%); width: min(100%, 48rem); box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.25);"
      >
        <% drawer_authed = authed?(@current_scope) %>

        <.sponster_drawer_header
          wallet_balance={@current_scope && @current_scope.wallet_balance}
          user_alias={@current_scope && @current_scope.user && @current_scope.user.alias}
          authed={drawer_authed}
          on_close={Phoenix.LiveView.JS.push("close_sponster_drawer")}
        />

        <div class="flex-1 overflow-hidden relative min-h-0">
          <%= if @current_scope && @current_scope.user do %>
            <div class="absolute inset-0 overflow-y-auto p-4 z-10">
              <%= if @loading_offers do %>
                <div class="flex items-center justify-center py-12">
                  <span class="loading loading-spinner loading-lg"></span>
                </div>
              <% else %>
                <%= if Enum.empty?(@video_offers) && Enum.empty?(@active_offers) do %>
                  <div class="py-10 px-4 max-w-md mx-auto text-base-content/80 text-center">
                    <h2 class="h2 font-semibold text-lg text-base-content">
                      No ads available right now.
                    </h2>
                    <p class="text-sm mt-1">Try back later.</p>
                    <p class="text-sm mt-5 text-base-content/70">
                      Want to maximize sponsorships?
                    </p>
                    <div class="mt-4 flex flex-col gap-3">
                      <a
                        href={@me_file_sponsorship_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class={[
                          "btn btn-widget btn-widget-emphasis btn-lg rounded-full border-[1.5px] w-full min-h-16",
                          "px-6 py-4 h-auto leading-snug font-semibold",
                          "inline-flex items-center justify-between gap-3 transition-colors text-left",
                          "outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/40"
                        ]}
                      >
                        <span class="flex min-w-0 items-center gap-3">
                          <img
                            src="/images/youdata_gray_square.svg"
                            alt=""
                            class="h-10 w-10 shrink-0 rounded-md object-contain"
                            decoding="async"
                          />
                          <span class="leading-snug">Optimize your MeFile</span>
                        </span>
                        <.icon
                          name="hero-arrow-top-right-on-square"
                          class="h-6 w-6 shrink-0 text-base-content/35"
                        />
                      </a>
                      <a
                        href={@settings_notifications_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class={[
                          "btn btn-widget-ghost btn-lg rounded-full w-full min-h-16",
                          "px-6 py-4 h-auto leading-snug font-semibold",
                          "inline-flex items-center justify-between gap-3 transition-colors text-left",
                          "outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/40"
                        ]}
                      >
                        <span class="flex min-w-0 items-center gap-3">
                          <.icon name="hero-megaphone" class="h-7 w-7 shrink-0 text-base-content/55" />
                          <span class="leading-snug">Set notifications</span>
                        </span>
                        <.icon
                          name="hero-arrow-top-right-on-square"
                          class="h-6 w-6 shrink-0 text-base-content/35"
                        />
                      </a>
                    </div>
                    <div class="mt-4 space-y-1 text-xs text-base-content/50 leading-snug text-center">
                      <p>Better data = better sponsors + more revenue</p>
                      <p>Receive alerts when you have ads.</p>
                    </div>
                  </div>
                <% else %>
                  <%= if @show_ad_type_tabs do %>
                    <.ad_type_tabs
                      selected_ad_type={@selected_ad_type}
                      three_tap_ad_count={length(@active_offers)}
                      video_ad_count={length(@video_offers)}
                    />
                  <% end %>

                  <%= if @selected_ad_type == "three_tap" do %>
                    <%= if Enum.empty?(@active_offers) do %>
                      <div class="text-center text-base-content/70 py-8">
                        No 3-Tap ads available
                      </div>
                    <% else %>
                      <div class="max-w-3xl mx-auto w-full">
                        <.live_component
                          module={QlariusWeb.ThreeTapStackComponent}
                          id={"#{@announcer_id_prefix}-three-tap-stack"}
                          active_offers={@active_offers}
                          user_ip={@user_ip}
                          current_scope={@current_scope}
                          host_uri={@host_uri}
                          recipient={@recipient}
                          tip_only={@tip_only}
                        />
                      </div>
                    <% end %>
                  <% else %>
                    <.video_offer_list
                      video_offers={@video_offers}
                      completed_video_offers={@completed_video_offers}
                      me_file_id={@current_scope.user.me_file && @current_scope.user.me_file.id}
                      recipient={@recipient}
                      tip_only={@tip_only}
                      loading={@loading_offers}
                    />
                  <% end %>
                <% end %>
              <% end %>
            </div>
          <% else %>
            <div class="absolute inset-0 z-10 flex flex-col min-h-0 page-canvas">
              <iframe
                src={@info_iframe_src}
                class="w-full flex-1 min-h-0 border-0"
                title="What is Sponster?"
                loading="lazy"
                referrerpolicy="no-referrer-when-downgrade"
              />
            </div>
          <% end %>

          <div
            class={[
              "absolute inset-0 bg-black/30 backdrop-blur-sm transition-opacity duration-300 z-20",
              if(@show_split_drawer, do: "opacity-100", else: "opacity-0 pointer-events-none")
            ]}
            phx-click="toggle_split_drawer"
          />

          <%= if @current_scope && @current_scope.user && @recipient do %>
            <%= if @tip_only do %>
              <% tip_disclaimer_open? = @sponster_disclaimer_dock_visible %>
              <% tip_panel_state =
                cond do
                  @show_split_drawer -> "open"
                  @sponster_disclaimer_dock_visible -> "peek"
                  true -> "recessed"
                end %>
              <% tip_panel_slide =
                cond do
                  @show_split_drawer -> "translate-y-0"
                  @sponster_disclaimer_dock_visible -> "qlink-split-panel--peek"
                  true -> "translate-y-[calc(100%-2.75rem+10px)]"
                end %>
              <div
                id={@split_panel_id}
                phx-hook="QlinkSplitDisclaimerPeek"
                data-split-panel-state={tip_panel_state}
                class={[
                  "absolute inset-x-0 bottom-0 z-30 flex max-h-[90%] min-h-0 flex-col transition-transform duration-500 ease-out",
                  tip_panel_slide
                ]}
              >
                <div class={[
                  "pointer-events-none relative z-10 flex w-full flex-shrink-0 justify-end bg-transparent",
                  if(@show_split_drawer, do: "border-b border-base-content/10", else: "border-b-0")
                ]}>
                  <div class="pointer-events-auto shrink-0">
                    <.creator_tip_tab />
                  </div>
                </div>
                <div
                  id={"#{@announcer_id_prefix}-split-disclaimer-slot"}
                  data-disclaimer-slot
                  class={[
                    "w-full shrink-0 overflow-hidden transition-[max-height] duration-500 ease-out",
                    if(tip_disclaimer_open?, do: "max-h-[10rem]", else: "max-h-0")
                  ]}
                  aria-hidden={if tip_disclaimer_open?, do: "false", else: "true"}
                >
                  <.ads_disclaimer_bar
                    id={"#{@announcer_id_prefix}-ads-disclaimer-bar"}
                    class="w-full shadow-sm"
                  />
                </div>
                <.creator_tip_drawer_panel
                  recipient={@recipient}
                  creator={@creator}
                  wallet_balance={@current_scope.wallet_balance}
                  show={@show_split_drawer}
                />
              </div>
            <% else %>
              <%= if @show_split_reminder do %>
                <.split_reminder_tip
                  id={"split-reminder-tip-#{@announcer_id_prefix}"}
                  split_amount={
                    (@current_scope.user.me_file && @current_scope.user.me_file.split_amount) || 50
                  }
                />
              <% end %>
              <% split_disclaimer_open? = @sponster_disclaimer_dock_visible %>
              <% split_panel_state =
                cond do
                  @show_split_drawer -> "open"
                  @sponster_disclaimer_dock_visible -> "peek"
                  true -> "recessed"
                end %>
              <% split_slide =
                cond do
                  @show_split_drawer -> "translate-y-0"
                  @sponster_disclaimer_dock_visible -> "qlink-split-panel--peek"
                  true -> "translate-y-[calc(100%-2.75rem+10px)]"
                end %>
              <div
                id={@split_panel_id}
                phx-hook="QlinkSplitDisclaimerPeek"
                data-split-panel-state={split_panel_state}
                class={[
                  "absolute inset-x-0 bottom-0 z-30 flex max-h-[90%] min-h-0 flex-col transition-transform duration-500 ease-out",
                  split_slide
                ]}
              >
                <div class={[
                  "pointer-events-none relative z-10 flex w-full flex-shrink-0 justify-end bg-transparent",
                  if(@show_split_drawer, do: "border-b border-base-content/10", else: "border-b-0")
                ]}>
                  <div class="pointer-events-auto shrink-0">
                    <.split_tab split_amount={
                      (@current_scope.user.me_file && @current_scope.user.me_file.split_amount) || 50
                    } />
                  </div>
                </div>
                <div
                  id={"#{@announcer_id_prefix}-split-disclaimer-slot"}
                  data-disclaimer-slot
                  class={[
                    "w-full shrink-0 overflow-hidden transition-[max-height] duration-500 ease-out",
                    if(split_disclaimer_open?, do: "max-h-[10rem]", else: "max-h-0")
                  ]}
                  aria-hidden={if split_disclaimer_open?, do: "false", else: "true"}
                >
                  <.ads_disclaimer_bar
                    id={"#{@announcer_id_prefix}-ads-disclaimer-bar"}
                    class="w-full shadow-sm"
                  />
                </div>
                <div class="flex min-h-0 flex-1 flex-col overflow-hidden bg-base-200">
                  <div class="w-full bg-base-100 border-b border-base-300 p-5 flex justify-between items-center shadow-sm flex-shrink-0">
                    <div class="text-base-content font-bold uppercase tracking-wider text-sm">
                      TIP TO SUPPORT WHAT MATTERS
                    </div>
                    <button
                      phx-click="toggle_split_drawer"
                      type="button"
                      class="qlink-split-drawer-close flex items-center justify-center w-10 h-10 rounded-full border border-base-300 bg-base-100 shadow cursor-pointer transition-colors outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
                    >
                      <.icon name="hero-chevron-down" class="w-6 h-6 text-base-content" />
                    </button>
                  </div>

                  <div class="flex min-h-0 flex-1 flex-col gap-3 md:gap-8 overflow-y-auto bg-base-200 px-4 md:px-8 pb-6 md:pb-12 pt-4 md:pt-6 max-w-3xl mx-auto mt-1 md:!flex-row">
                    <div class="flex-1 flex flex-col items-center md:items-start">
                      <.auto_split_controls
                        split_amount={
                          (@current_scope.user.me_file && @current_scope.user.me_file.split_amount) ||
                            50
                        }
                      />

                      <div class="divider my-2 md:my-4 w-full max-w-[280px] mx-auto"></div>

                      <div class="text-lg font-bold text-base-content mb-1">InstaTip</div>
                      <div class="text-base-content/70 text-sm mb-2 md:mb-4 inline-flex flex-wrap items-center gap-1">
                        Instantly tip from your wallet
                        <.icon name="hero-arrow-right" class="w-4 h-4 inline-block shrink-0" />
                        <.wallet_balance
                          id={"#{@announcer_id_prefix}-tip-drawer-wallet"}
                          balance={@current_scope.wallet_balance}
                          compact?={true}
                        />
                      </div>
                      <.insta_tip_button_group
                        amounts={["0.25", "0.50", "1.00", "2.00"]}
                        wallet_balance={@current_scope.wallet_balance}
                        recipient_id={@recipient && @recipient.id}
                      />
                    </div>

                    <div class="border-divider-color my-2 md:my-4 w-full max-w-[280px] mx-auto md:hidden">
                    </div>

                    <div class="flex-1 flex flex-col items-center pt-1 md:pt-0">
                      <div class="text-2xl font-bold text-base-content mb-1 md:mb-2 text-center">
                        {@recipient.name || "Recipient"}
                      </div>
                      <div class="flex flex-col items-center gap-2 md:gap-4">
                        <div class="w-32 md:w-40 h-auto bg-base-300 shadow-md flex items-center justify-center overflow-hidden rounded">
                          <img
                            src={recipient_brand_image_url(@recipient, creator: @creator)}
                            alt={@recipient.name || "Recipient"}
                            class="object-contain w-full h-full"
                          />
                        </div>
                        <div class="text-base-content/70 text-sm text-center max-w-xs">
                          {@recipient.message ||
                            "Thank you for supporting this content. Your Sponster tips are greatly appreciated!"}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%= if not drawer_authed do %>
          <div class="flex-shrink-0 page-canvas border-t border-base-300/60 px-4 pt-3 pb-2 flex flex-col items-center gap-2 text-center">
            <p class="text-sm sm:text-base text-base-content font-medium tracking-tight leading-snug">
              Connect and sign up for free. Your wallet awaits.
            </p>
            <a
              href={@sponster_info_outbound_url}
              target="_blank"
              rel="noopener noreferrer"
              class={[
                "btn btn-widget-ghost btn-sm rounded-full border-[1.5px]",
                "inline-flex items-center gap-1.5 px-4 font-semibold",
                "outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/40"
              ]}
            >
              <span>More Sponster Info</span>
              <span aria-hidden="true">→</span>
            </a>
            <div class="flex justify-center" aria-hidden="true">
              <.icon
                name="hero-chevron-down"
                class="w-7 h-7 text-sponster-600 qlink-sponster-drawer-cta-chevron"
              />
            </div>
          </div>
        <% end %>
      </div>


      <.sponster_announcer_bar
        id_prefix={@announcer_id_prefix}
        current_scope={@current_scope}
        show_sponster_drawer={@show_sponster_drawer}
        on_auth_click={@on_auth_click}
        connect_href={@connect_href}
        connect_link_target={@connect_link_target}
        anon_display={@announcer_anon_display}
      />
    <% end %>
    """
  end
end
