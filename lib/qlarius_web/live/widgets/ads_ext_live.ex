defmodule QlariusWeb.Widgets.AdsExtLive do
  @moduledoc """
  Third-party embed surface for the Sponster experience: announcer bar +
  ad/tip drawer in a single bottom-anchored iframe.

  Renders the same shared stack as Qlink pages
  (`QlariusWeb.Components.SponsterPublicPage.sponster_stack/1`) with the
  announcer in `anon_display: :promo` mode for anonymous visitors
  (rotating banners + bouncing coin). The page background is transparent
  (see the `html, #app` rule in app.css) so only the fixed bottom stack
  paints inside the host page.

  The embed script (`priv/static/sponster-tipjar-widget-ext-script.js`)
  creates one collapsed bottom iframe. The collapsed height depends on the
  viewer: 80px for anonymous visitors (50px bar + 30px promo/coin
  headroom) and 60px for authed viewers (50px bar + ~10px upward shadow
  headroom). The `SponsterWidgetBridge` hook reports the right
  height to the host page on mount. When the drawer or any modal
  opens/closes, this LV posts `sponster_widget_expand` /
  `sponster_widget_collapse` messages and the script resizes the iframe
  to full viewport height / back to the collapsed height.
  """
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias QlariusWeb.SponsterRecipientSurface

  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.SponsterPublicPage, only: [sponster_stack: 1]
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.Widgets.UnauthCTA

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  # `current_scope` is assigned by the `/widgets` live_session
  # (`:mount_current_scope`, uses `assign_new`). Anonymous visitors mount
  # with `current_scope: nil` — the stack renders the promo announcer and
  # the info drawer instead of crashing.
  on_mount {QlariusWeb.UserAuth, :mount_current_scope}

  @impl true
  def mount(params, _session, socket) do
    split_code = Map.get(params, "split_code")
    recipient = Users.get_recipient_by_split_code(split_code)

    socket =
      socket
      |> assign(:page_title, "Sponster")
      |> assign(:split_code, split_code)
      |> assign(:auth_referral_context, Qlarius.Referrals.Context.none())
      |> SponsterRecipientSurface.init_assigns(recipient)

    socket =
      if connected?(socket) && socket.assigns.current_scope do
        SponsterRecipientSurface.subscribe(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    was_expanded = expanded?(socket)

    case SponsterRecipientSurface.handle_event(event, params, socket) do
      {:handled, socket} -> {:noreply, notify_parent_of_resize(socket, was_expanded)}
      :unhandled -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info(msg, socket) do
    was_expanded = expanded?(socket)

    case SponsterRecipientSurface.handle_info(msg, socket) do
      {:handled, socket} -> {:noreply, notify_parent_of_resize(socket, was_expanded)}
      :unhandled -> {:noreply, socket}
    end
  end

  # The iframe must be full-height whenever anything beyond the 80px
  # announcer strip is visible: the drawer, or any modal that can outlive
  # a drawer close (video player, tip modals, connect interstitial,
  # AuthSheet).
  defp expanded?(socket) do
    a = socket.assigns

    !!(a[:show_sponster_drawer] || a[:show_video_player] || a[:show_insta_tip_modal] ||
         a[:show_insta_tip_thanks_modal] || a[:show_connect_modal] || a[:show_auth_sheet])
  end

  # Tell the embed script to grow/shrink the iframe when the expanded
  # state flips. The `PostMessage` hook forwards this to `window.parent`.
  defp notify_parent_of_resize(socket, was_expanded) do
    expanded = expanded?(socket)

    if expanded != was_expanded do
      push_event(socket, "send-post-message", %{
        type: if(expanded, do: "sponster_widget_expand", else: "sponster_widget_collapse")
      })
    else
      socket
    end
  end

  # Whether the in-place AuthSheet should be rendered on this mount.
  # Standalone widget surface — governed by the `:on_widget_standalone`
  # flag, same as `InstaTipWidgetLive`. Anonymous visitors only.
  def auth_sheet_enabled?(assigns) do
    anonymous? =
      is_nil(assigns[:current_scope]) or is_nil(assigns[:current_scope].true_user)

    flag_on? =
      Application.get_env(:qlarius, :auth_sheet, [])
      |> Keyword.get(:on_widget_standalone, false)

    flag_on? and anonymous?
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Collapsed height: authed viewers need the 50px bar plus headroom
         for the upward box-shadow; anon viewers get 30px extra for promo
         banners + coin peek. --%>
    <div
      id="ads-ext-postmessage-bridge"
      phx-hook="SponsterWidgetBridge"
      data-collapsed-height={if authed?(@current_scope), do: "60", else: "80"}
      class="hidden"
      aria-hidden="true"
    >
    </div>

    <%= if @recipient do %>
      <% widget_on_click =
        if auth_sheet_enabled?(assigns),
          do: Phoenix.LiveView.JS.push("open_auth_sheet", value: %{brand: "sponster"}),
          else: nil %>

      <.sponster_stack
        recipient={@recipient}
        info_context={:default}
        current_scope={@current_scope}
        show_sponster_drawer={@show_sponster_drawer}
        show_split_drawer={@show_split_drawer}
        show_split_reminder={@show_split_reminder}
        sponster_disclaimer_dock_visible={@sponster_disclaimer_dock_visible}
        loading_offers={@loading_offers}
        active_offers={@active_offers}
        video_offers={@video_offers}
        completed_video_offers={@completed_video_offers}
        selected_ad_type={@selected_ad_type}
        show_ad_type_tabs={@show_ad_type_tabs}
        host_uri={@host_uri}
        me_file_sponsorship_url={@me_file_sponsorship_url}
        settings_notifications_url={@settings_notifications_url}
        user_ip={assigns[:user_ip] || "0.0.0.0"}
        on_auth_click={widget_on_click}
        connect_link_target="_top"
        announcer_id_prefix="ads-ext"
        split_panel_id="ads-ext-split-settings-panel"
        announcer_anon_display={:promo}
      />

      <%!-- Video Player Modal --%>
      <%= if @show_video_player && @current_video_offer do %>
        <% video_modal_enter =
          Phoenix.LiveView.JS.transition(
            {"transition-opacity ease-out duration-200", "opacity-0", "opacity-100"},
            time: 200
          )
          |> Phoenix.LiveView.JS.transition(
            {"transition ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"},
            to: "#video-player-content",
            time: 300
          ) %>
        <% video_modal_leave =
          Phoenix.LiveView.JS.hide(
            transition: {"transition-opacity ease-in duration-200", "opacity-100", "opacity-0"},
            time: 200
          )
          |> Phoenix.LiveView.JS.hide(
            to: "#video-player-content",
            transition:
              {"transition ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-95"},
            time: 200
          ) %>
        <div
          id="video-player-modal"
          class="fixed inset-0 z-[70] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6"
          phx-click="close_video_player"
          phx-mounted={video_modal_enter}
          phx-remove={video_modal_leave}
        >
          <div
            id="video-player-content"
            class={"relative flex w-full max-w-2xl max-h-[90vh] flex-col overflow-hidden bg-base-100 shadow-2xl #{modal_panel_radius_class()}"}
            phx-click={%Phoenix.LiveView.JS{}}
          >
            <div class="flex items-start justify-between gap-3 border-b border-base-300 px-6 pt-5 pb-4">
              <div class="min-w-0">
                <div class="text-2xl font-bold leading-none">
                  ${Decimal.round(@current_video_offer.offer_amt || Decimal.new("0"), 2)}
                </div>
                <p
                  class="mt-1.5 truncate text-sm text-base-content/60"
                  title={@current_video_offer.media_run.media_piece.ad_category.ad_category_name}
                >
                  {@current_video_offer.media_run.media_piece.ad_category.ad_category_name}
                </p>
              </div>
              <button
                phx-click="close_video_player"
                type="button"
                class="btn btn-circle btn-sm btn-ghost shrink-0 outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
                aria-label="Close video player"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <div class="overflow-y-auto px-6 pt-5 pb-3">
              <.video_player
                current_video_offer={@current_video_offer}
                video_payment_collected={@video_payment_collected}
                show_replay_button={@show_replay_button}
              />
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Video Collection Drawer --%>
      <%= if @current_video_offer && @show_video_player do %>
        <.video_collection_drawer
          current_video_offer={@current_video_offer}
          show_collection_drawer={
            @show_collection_drawer &&
              (@video_watched_complete || @video_payment_collected || @show_replay_button)
          }
          video_payment_collected={@video_payment_collected}
          show_replay_button={@show_replay_button}
          closing={@drawer_closing}
          has_bottom_dock={false}
          z_class="z-[70]"
        />
      <% end %>

      <%!-- InstaTip Modals --%>
      <%= if @current_scope do %>
        <% tip_recipient = @insta_tip_recipient || @recipient %>
        <.insta_tip_modal
          show={@show_insta_tip_modal}
          recipient_name={(tip_recipient && tip_recipient.name) || "Recipient"}
          recipient_id={tip_recipient && tip_recipient.id}
          amount={@insta_tip_amount || Decimal.new("0.00")}
          current_balance={@current_scope.wallet_balance}
        />

        <.insta_tip_thanks_modal
          show={@show_insta_tip_thanks_modal}
          recipient_name={@insta_tip_thanks_recipient || "Recipient"}
          amount={@insta_tip_thanks_amount || Decimal.new("0.00")}
        />
      <% end %>

      <%!-- Connect-wallet interstitial for anonymous wallet-required taps. --%>
      <.connect_wallet_modal
        show={@show_connect_modal}
        scope={@current_scope}
        connect_brand={:sponster}
        on_click={widget_on_click}
      />

      <%!-- In-place AuthSheet (`:on_widget_standalone` flag). --%>
      <%= if auth_sheet_enabled?(assigns) do %>
        <.live_component
          module={QlariusWeb.Components.AuthSheet}
          id="ads-ext-auth-sheet"
          show={@show_auth_sheet}
          surface={:on_widget_standalone}
          referral_context={@auth_referral_context}
          client_ip={assigns[:user_ip] || "0.0.0.0"}
          connect_brand={:sponster}
          on_cancel={Phoenix.LiveView.JS.push("close_auth_sheet")}
        />
      <% end %>
    <% end %>
    """
  end
end
