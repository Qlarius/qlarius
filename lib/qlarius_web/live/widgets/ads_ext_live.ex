defmodule QlariusWeb.Widgets.AdsExtLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  # Commented out unused alias - Sponster not directly referenced (only string "Sponster" used)
  # alias Qlarius.Sponster
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Offer
  # Commented out unused alias - User not directly referenced in this file
  # alias Qlarius.Accounts.User
  # Commented out unused aliases - LedgerHeader/LedgerEntry not directly referenced in this file
  # alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  # Commented out unused alias - AdEvent not directly referenced in this file
  # alias Qlarius.Sponster.AdEvent
  # Commented out unused alias - Recipient not directly referenced in this file
  # alias Qlarius.Sponster.Recipient
  alias Qlarius.Repo
  # Commented out unused alias - Scope not directly referenced in this file
  # alias Qlarius.Accounts.Scope
  # Commented out unused alias - ThreeTap not directly referenced in this file
  # alias Qlarius.Sponster.Ads.ThreeTap
  # Commented out unused alias - Component not directly referenced in this file
  # alias Phoenix.Component
  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster
  # Commented out unused import - OfferHTML functions not used in this LiveView
  # import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Money, only: [format_usd: 1]
  import QlariusWeb.InstaTipComponents
  import QlariusWeb.Components.AdsComponents
  # Commented out unused import - Layouts functions not used in this LiveView
  # import QlariusWeb.Layouts

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(params, _session, socket) do
    # Load initial data during first mount
    # User and current_scope extracted for clarity but not directly used in this function
    _user = socket.assigns.current_scope.user
    _current_scope = socket.assigns.current_scope

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    split_code = Map.get(params, "split_code")
    recipient = Users.get_recipient_by_split_code(split_code)

    {show_ad_type_tabs, selected_ad_type} =
      QlariusWeb.Components.AdsComponents.determine_ad_type_display(
        socket.assigns.current_scope.three_tap_ad_count,
        socket.assigns.current_scope.video_ad_count
      )

    socket =
      socket
      |> assign(:active_offers, [])
      |> assign(:video_offers, [])
      |> assign(:selected_ad_type, selected_ad_type)
      |> assign(:loading, true)
      |> assign(:host_uri, host_uri)
      |> assign(:split_code, split_code)
      |> assign(:recipient, recipient)
      |> assign(:page_title, "Sponster")
      |> assign(:show_insta_tip_modal, false)
      |> assign(:insta_tip_amount, nil)
      |> assign(:show_video_player, false)
      |> assign(:current_video_offer, nil)
      |> assign(:video_watched_complete, false)
      |> assign(:show_replay_button, false)
      |> assign(:video_payment_collected, false)
      |> assign(:completed_video_offers, [])
      |> assign(:show_ad_type_tabs, show_ad_type_tabs)
      |> assign(:show_collection_drawer, false)
      |> assign(:drawer_closing, false)
      |> assign(
        :current_balance,
        Wallets.get_user_current_balance(socket.assigns.current_scope.user)
      )

    if connected?(socket) do
      send(self(), :load_offers)

      MeFileStatsBroadcaster.subscribe_to_me_file_stats(
        socket.assigns.current_scope.user.me_file.id
      )

      # Subscribe to InstaTip notifications
      Phoenix.PubSub.subscribe(Qlarius.PubSub, "user:#{socket.assigns.current_scope.user.id}")

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:load_offers, socket) do
    me_file_id = socket.assigns.current_scope.user.me_file.id

    three_tap_query =
      from(o in Offer,
        join: mp in assoc(o, :media_piece),
        where:
          o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 1,
        order_by: [desc: o.offer_amt],
        preload: [media_piece: :ad_category]
      )

    active_offers =
      three_tap_query
      |> Repo.all()
      |> Enum.map(fn offer -> {offer, 0} end)

    video_query =
      from(o in Offer,
        join: mp in assoc(o, :media_piece),
        where:
          o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 2,
        preload: [media_run: [media_piece: :ad_category]]
      )

    video_offers = Repo.all(video_query)

    video_offers_with_rate =
      Enum.map(video_offers, fn offer ->
        duration = offer.media_run.media_piece.duration || 1
        rate = Decimal.div(offer.offer_amt || Decimal.new("0"), Decimal.new(duration))
        {offer, rate}
      end)
      |> Enum.sort_by(fn {_offer, rate} -> Decimal.to_float(rate) end, :desc)

    {:noreply,
     socket
     |> assign(:active_offers, active_offers)
     |> assign(:video_offers, video_offers_with_rate)
     |> assign(:loading, false)}
  end

  # me_file_id from message not used - we get me_file from socket.assigns instead
  @impl true
  def handle_info({:refresh_wallet_balance, _me_file_id}, socket) do
    new_balance =
      Wallets.get_me_file_ledger_header_balance(socket.assigns.current_scope.user.me_file)

    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:me_file_balance_updated, new_balance}, socket) do
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

    {:noreply,
     socket
     |> assign(:current_scope, current_scope)
     |> assign(:current_balance, new_balance)
     |> push_event("update-balance", %{balance: Decimal.to_string(new_balance, :normal)})}
  end

  @impl true
  def handle_info("insta_tip_success", socket) do
    {:noreply, put_flash(socket, :info, "InstaTip sent successfully!")}
  end

  @impl true
  def handle_info("insta_tip_failure", socket) do
    {:noreply, put_flash(socket, :error, "InstaTip failed. Please try again.")}
  end

  @impl true
  def handle_info({:me_file_offers_updated, _me_file_id}, socket) do
    # Don't reload offers here - let completed offers (phase 3) stay visible
    # Offers will refresh on next mount/page load
    {:noreply, socket}
  end

  @impl true
  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info(:show_collection_drawer, socket) do
    {:noreply, assign(socket, :show_collection_drawer, true)}
  end

  @impl true
  def handle_info(:auto_close_drawer, socket) do
    socket = assign(socket, :drawer_closing, true)
    Process.send_after(self(), :finish_closing_drawer, 300)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:finish_closing_drawer, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_collection_drawer, false)
     |> assign(:drawer_closing, false)}
  end

  @impl true
  def handle_event("set_split", %{"split" => split}, socket) do
    split_amount = String.to_integer(split)
    me_file = socket.assigns.current_scope.user.me_file

    case MeFile.update_me_file_split_amount(me_file, split_amount) do
      {:ok, updated_me_file} ->
        current_scope =
          Map.put(
            socket.assigns.current_scope,
            :user,
            Map.put(socket.assigns.current_scope.user, :me_file, updated_me_file)
          )

        {:noreply, assign(socket, :current_scope, current_scope)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("initiate_insta_tip", %{"amount" => amount_str}, socket) do
    amount = Decimal.new(to_string(amount_str))

    socket =
      socket
      |> assign(:insta_tip_amount, amount)
      |> assign(:show_insta_tip_modal, true)
      |> assign(
        :current_balance,
        Wallets.get_user_current_balance(socket.assigns.current_scope.user)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_insta_tip", %{"amount" => amount_str}, socket) do
    amount = Decimal.new(amount_str)
    user = socket.assigns.current_scope.user
    recipient = socket.assigns.recipient

    case Wallets.create_insta_tip_request(user, recipient, amount, user) do
      {:ok, _ledger_event} ->
        new_balance = Decimal.sub(socket.assigns.current_scope.wallet_balance, amount)
        current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)

        {:noreply,
         socket
         |> assign(:current_scope, current_scope)
         |> assign(:current_balance, new_balance)
         |> assign(:show_insta_tip_modal, false)
         |> assign(:insta_tip_amount, nil)
         |> push_event("update-balance", %{balance: Decimal.to_string(new_balance, :normal)})
         |> put_flash(:info, "InstaTip of #{format_usd(amount)} sent! Processing...")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_insta_tip_modal, false)
         |> assign(:insta_tip_amount, nil)
         |> put_flash(:error, "Failed to send InstaTip. Please try again.")}
    end
  end

  @impl true
  def handle_event("cancel_insta_tip", _params, socket) do
    socket =
      socket
      |> assign(:show_insta_tip_modal, false)
      |> assign(:insta_tip_amount, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close-insta-tip-modal", _params, socket) do
    socket =
      socket
      |> assign(:show_insta_tip_modal, false)
      |> assign(:insta_tip_amount, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_ad_type", %{"type" => ad_type}, socket) do
    {:noreply, assign(socket, :selected_ad_type, ad_type)}
  end

  @impl true
  def handle_event("open_video_ad", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    {offer, _rate} =
      Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end)

    {:noreply,
     socket
     |> assign(:current_video_offer, offer)
     |> assign(:show_video_player, true)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:show_collection_drawer, false)}
  end

  @impl true
  def handle_event("close_video_player", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_player, false)
     |> assign(:current_video_offer, nil)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)
     |> assign(:show_collection_drawer, false)}
  end

  @impl true
  def handle_event("video_watched_complete", _params, socket) do
    # Check if this video has already been collected (don't show drawer for replay)
    already_collected = socket.assigns.current_video_offer.id in socket.assigns.completed_video_offers

    if already_collected do
      {:noreply, socket}
    else
      socket = assign(socket, :video_watched_complete, true)
      Process.send_after(self(), :show_collection_drawer, 100)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    case Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end) do
      nil ->
        {:noreply, put_flash(socket, :error, "Offer not found")}

      {offer, _rate} ->
        recipient = socket.assigns.recipient
        split_amount = socket.assigns.current_scope.user.me_file.split_amount || 0
        user_ip = socket.assigns[:user_ip] || "0.0.0.0"

        case Qlarius.Sponster.Ads.Video.create_video_ad_event(offer, recipient, split_amount, user_ip) do
          {:ok, _ad_event} ->
            completed_ids = [offer_id | socket.assigns.completed_video_offers]
            Process.send_after(self(), :auto_close_drawer, 3000)

            {:noreply,
             socket
             |> assign(:video_watched_complete, false)
             |> assign(:show_replay_button, false)
             |> assign(:video_payment_collected, true)
             |> assign(:completed_video_offers, completed_ids)
             |> put_flash(:info, "Payment collected!")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to collect payment")}
        end
    end
  end

  @impl true
  def handle_event("video_collect_timeout", _params, socket) do
    Process.send_after(self(), :auto_close_drawer, 3000)

    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, true)
     |> assign(:show_collection_drawer, true)}
  end

  @impl true
  def handle_event("replay_video", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)
     |> assign(:show_collection_drawer, false)
     |> assign(:drawer_closing, false)
     |> push_event("replay-video", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tipjar_container {assigns}>
      <div class="bg-base-100 dark:!bg-base-300">
        <%= if !@loading && Enum.empty?(@active_offers) && Enum.empty?(@video_offers) do %>
          <div class="flex items-center justify-center min-h-screen px-4">
            <p class="text-xl text-base-content/70 text-center">
              You current have no ad offers. For optimal results, make sure your MeFile is rich and accurate.
            </p>
          </div>
        <% else %>
          <div class="container min-h-screen h-fit mx-auto px-4 py-8 max-w-3xl mt-[60px]">
            <%= if @show_ad_type_tabs do %>
              <.ad_type_tabs
                selected_ad_type={@selected_ad_type}
                three_tap_ad_count={@current_scope.three_tap_ad_count || 0}
                video_ad_count={@current_scope.video_ad_count || 0}
              />
            <% end %>

            <%= if @selected_ad_type == "three_tap" do %>
              <%= if Enum.empty?(@active_offers) do %>
                <div class="text-center text-base-content/70 py-8">
                  No 3-Tap ads available
                </div>
              <% else %>
                <.live_component
                  module={QlariusWeb.ThreeTapStackComponent}
                  id="three-tap-stack"
                  active_offers={@active_offers}
                  user_ip={@user_ip}
                  current_scope={@current_scope}
                  host_uri={@host_uri}
                  recipient={@recipient}
                />
              <% end %>
            <% else %>
              <%= if !@loading && Enum.empty?(@video_offers) do %>
                <div class="text-center text-base-content/70 py-8">
                  No video ads available
                </div>
              <% else %>
                <ul class="-mx-4 sm:mx-0 list bg-base-200 dark:!bg-base-200 sm:rounded-box shadow-md overflow-hidden">
                  <.video_offer_list_item
                    :for={{offer, rate} <- @video_offers}
                    offer={offer}
                    rate={rate}
                    completed={offer.id in @completed_video_offers}
                    me_file_id={@current_scope.user.me_file && @current_scope.user.me_file.id}
                    recipient={@recipient}
                  />
                </ul>
              <% end %>
            <% end %>
          </div>
        <% end %>

        <%= if @show_video_player && @current_video_offer do %>
          <div
            class="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-2 animate-fade-in"
            phx-click="close_video_player"
          >
            <div
              class="bg-base-100 rounded-lg max-w-2xl w-full max-h-[90vh] overflow-auto animate-fade-in"
              phx-click={JS.exec("phx-click", to: "#video-player-content")}
            >
              <div id="video-player-content" class="p-3">
                <div class="flex justify-between items-center mb-3">
                  <h2 class="text-lg font-bold">
                    <%= @current_video_offer.media_run.media_piece.ad_category.ad_category_name %>
                  </h2>
                  <button
                    class="btn btn-sm btn-circle btn-ghost"
                    phx-click="close_video_player"
                  >
                    ✕
                  </button>
                </div>

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
            show_collection_drawer={@show_collection_drawer && (@video_watched_complete || @video_payment_collected || @show_replay_button)}
            video_payment_collected={@video_payment_collected}
            show_replay_button={@show_replay_button}
            closing={@drawer_closing}
            has_bottom_dock={false}
          />
        <% end %>
      </div>
    </Layouts.tipjar_container>

    <.insta_tip_modal
      show={@show_insta_tip_modal}
      recipient_name={(@recipient && @recipient.name) || "Recipient"}
      amount={@insta_tip_amount || Decimal.new("0.00")}
      current_balance={@current_scope.wallet_balance}
    />
    <Layouts.debug_assigns {assigns} />
    """
  end

  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
