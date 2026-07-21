defmodule QlariusWeb.Components.TiqitArqadeShell do
  @moduledoc """
  Layout shell for public Tiqit arqade pages: logo header, scrollable main,
  and optional Sponster announcer plus tipping modals.
  """

  use QlariusWeb, :html
  import QlariusWeb.Components.AdsComponents
  import QlariusWeb.Components.GiftModalComponents,
    only: [
      modal_backdrop_class: 0,
      modal_panel_radius_class: 0,
      tiqit_arqade_modal_border_class: 0
    ]
  import QlariusWeb.Components.SponsterPublicPage, only: [sponster_stack: 1]
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.Widgets.UnauthCTA

  alias QlariusWeb.TiqitArqade.Host

  slot :inner_block, required: true

  attr :recipient, :any, default: nil
  attr :creator, :any, default: nil
  attr :return_to, :string, required: true
  attr :current_scope, :any, default: nil
  attr :user_ip, :string, default: "0.0.0.0"
  attr :show_sponster_drawer, :boolean, default: false
  attr :show_split_drawer, :boolean, default: false
  attr :show_split_reminder, :boolean, default: false
  attr :sponster_disclaimer_dock_visible, :boolean, default: false
  attr :loading_offers, :boolean, default: false
  attr :active_offers, :list, default: []
  attr :offers_refresh_gen, :integer, default: 0
  attr :video_offers, :list, default: []
  attr :completed_video_offers, :list, default: []
  attr :selected_ad_type, :string, default: "three_tap"
  attr :show_ad_type_tabs, :boolean, default: false
  attr :host_uri, :any, default: nil
  attr :me_file_sponsorship_url, :string, default: nil
  attr :settings_notifications_url, :string, default: nil
  attr :show_video_player, :boolean, default: false
  attr :current_video_offer, :any, default: nil
  attr :video_payment_collected, :boolean, default: false
  attr :show_replay_button, :boolean, default: false
  attr :show_collection_drawer, :boolean, default: false
  attr :drawer_closing, :boolean, default: false
  attr :video_watched_complete, :boolean, default: false
  attr :show_insta_tip_modal, :boolean, default: false
  attr :insta_tip_amount, :any, default: nil
  attr :insta_tip_recipient, :any, default: nil
  attr :show_insta_tip_thanks_modal, :boolean, default: false
  attr :insta_tip_thanks_amount, :any, default: nil
  attr :insta_tip_thanks_recipient, :any, default: nil
  attr :show_connect_modal, :boolean, default: false
  attr :connect_modal_brand, :atom, default: :tiqit
  attr :show_auth_sheet, :boolean, default: false
  attr :auth_sheet_connect_brand, :atom, default: :tiqit
  attr :auth_referral_context, :any, default: nil
  attr :show_logout_modal, :boolean, default: false
  attr :main_class, :string, default: nil
  attr :announcer_id_prefix, :string, default: "tiqit-arqade"

  def shell(assigns) do
    ~H"""
    <div
      class="flex h-dvh flex-col overflow-hidden bg-base-100"
      data-arqade-in-app-page="true"
    >
      <header class="shrink-0 border-b border-base-300 bg-base-100">
        <div class="flex w-full items-center justify-center px-4 py-4">
          <img
            src="/images/Tiqit_logo_color_horiz.svg"
            alt="Tiqit"
            class="h-8 w-auto"
            decoding="async"
          />
        </div>
      </header>

      <main class={[
        "flex min-h-0 w-full flex-1 flex-col overflow-hidden",
        @recipient && "pb-[50px]",
        @main_class
      ]}>
        {render_slot(@inner_block)}
      </main>

      <%= if @recipient do %>
        <.sponster_stack
          recipient={@recipient}
          creator={@creator}
          info_context={:tiqit}
          current_scope={@current_scope}
          tip_only={true}
          show_sponster_drawer={@show_sponster_drawer}
          show_split_drawer={@show_split_drawer}
          show_split_reminder={@show_split_reminder}
          sponster_disclaimer_dock_visible={@sponster_disclaimer_dock_visible}
          loading_offers={@loading_offers}
          active_offers={@active_offers}
          offers_refresh_gen={@offers_refresh_gen}
          video_offers={@video_offers}
          completed_video_offers={@completed_video_offers}
          selected_ad_type={@selected_ad_type}
          show_ad_type_tabs={@show_ad_type_tabs}
          host_uri={@host_uri}
          me_file_sponsorship_url={@me_file_sponsorship_url}
          settings_notifications_url={@settings_notifications_url}
          user_ip={@user_ip}
          auth_sheet_enabled?={Host.auth_sheet_enabled?(assigns)}
          on_auth_click={
            if Host.auth_sheet_enabled?(assigns),
              do: Phoenix.LiveView.JS.push("open_auth_sheet", value: %{brand: "sponster"}),
              else: nil
          }
          connect_href={
            if Host.auth_sheet_enabled?(assigns),
              do: nil,
              else: ~p"/login?return_to=#{@return_to}"
          }
          connect_link_target="_self"
          announcer_id_prefix={@announcer_id_prefix}
          split_panel_id="tiqit-creator-tip-panel"
        />
      <% end %>

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
          class={"fixed inset-0 z-[70] #{modal_backdrop_class()} flex items-center justify-center p-4 sm:p-6"}
          phx-click="close_video_player"
          phx-mounted={video_modal_enter}
          phx-remove={video_modal_leave}
        >
          <div
            id="video-player-content"
            class={"relative flex w-full max-w-2xl max-h-[90vh] flex-col overflow-hidden bg-base-100 shadow-2xl #{modal_panel_radius_class()} #{tiqit_arqade_modal_border_class()}"}
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
                class="btn btn-circle btn-sm btn-ghost shrink-0"
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

      <.connect_wallet_modal
        show={@show_connect_modal}
        scope={@current_scope}
        connect_brand={@connect_modal_brand}
        on_click={
          if Host.auth_sheet_enabled?(assigns),
            do:
              Phoenix.LiveView.JS.push("open_auth_sheet",
                value: %{brand: Atom.to_string(@connect_modal_brand)}
              ),
            else: nil
        }
      />

      <%= if Host.auth_sheet_enabled?(assigns) do %>
        <.live_component
          module={QlariusWeb.Components.AuthSheet}
          id="tiqit-arqade-auth-sheet"
          show={@show_auth_sheet}
          surface={:on_qlink_page}
          referral_context={@auth_referral_context}
          client_ip={@user_ip}
          connect_brand={@auth_sheet_connect_brand}
          overlay_z_class="z-[160]"
          backdrop_class={modal_backdrop_class()}
          panel_border_class={tiqit_arqade_modal_border_class()}
          on_cancel={Phoenix.LiveView.JS.push("close_auth_sheet")}
        />
      <% end %>

      <%= if @current_scope && @show_logout_modal do %>
        <.modal
          id="tiqit-arqade-logout-modal"
          show={true}
          close_on_click_away={false}
          border_class={tiqit_arqade_modal_border_class()}
          on_cancel={JS.push("cancel_logout")}
        >
          <div class="rounded-box overflow-hidden">
            <div class="bg-base-200 px-6 py-4 rounded-t-box">
              <h3 class="font-bold text-lg">Disconnect wallet</h3>
            </div>
            <div class="p-6">
              <p class="py-4">You will leave this session on this page. You can connect again anytime.</p>
              <div class="modal-action">
                <button
                  type="button"
                  class="btn btn-ghost outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-base-content/35"
                  phx-click="cancel_logout"
                >
                  Cancel
                </button>
                <form action={~p"/logout"} method="post">
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                  <input type="hidden" name="return_to" value={@return_to} />
                  <button
                    type="submit"
                    class="btn btn-error outline-none focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-error-content/50"
                  >
                    Disconnect
                  </button>
                </form>
              </div>
            </div>
          </div>
        </.modal>
      <% end %>
    </div>
    """
  end
end
