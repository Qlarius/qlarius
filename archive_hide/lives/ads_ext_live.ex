defmodule QlariusWeb.AdsExtLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Sponster.Offer
  alias Qlarius.Repo
  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster
  alias Qlarius.YouData

  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Layouts
  import QlariusWeb.Components.AdsComponents

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(_params, _session, socket) do
    show_ad_type_tabs =
      socket.assigns.current_scope.three_tap_ad_count > 0 &&
        socket.assigns.current_scope.video_ad_count > 0

    socket =
      socket
      |> assign(:active_offers, [])
      |> assign(:video_offers, [])
      |> assign(:selected_ad_type, "three_tap")
      |> assign(:loading, true)
      |> assign(:show_video_player, false)
      |> assign(:current_video_offer, nil)
      |> assign(:video_watched_complete, false)
      |> assign(:show_replay_button, false)
      |> assign(:video_payment_collected, false)
      |> assign(:completed_video_offers, [])
      |> assign(:show_ad_type_tabs, show_ad_type_tabs)
      |> assign(:show_collection_drawer, false)
      |> assign(:drawer_closing, false)

    if connected?(socket) do
      send(self(), :load_offers)

      MeFileStatsBroadcaster.subscribe_to_me_file_stats(
        socket.assigns.current_scope.user.me_file.id
      )

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    split_code = Map.get(params, "split_code")
    recipient = Users.get_recipient_by_split_code(split_code)

    socket
    |> assign(:split_code, split_code)
    |> assign(:recipient, recipient)
    |> assign(:host_uri, URI.parse(uri))
    |> noreply()
  end

  @impl true
  def handle_event("set_split", %{"split" => split}, socket) do
    split_amount = String.to_integer(split)
    me_file = socket.assigns.current_scope.user.me_file

    case YouData.update_me_file_split_amount(me_file, split_amount) do
      {:ok, updated_me_file} ->
        {:noreply,
         socket |> assign(me_file: updated_me_file) |> assign(split_amount: split_amount)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("switch_ad_type", %{"type" => ad_type}, socket) do
    {:noreply, assign(socket, :selected_ad_type, ad_type)}
  end

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
  def handle_info(:show_collection_drawer, socket) do
    {:noreply, assign(socket, :show_collection_drawer, true)}
  end

  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)

    case Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end) do
      nil ->
        {:noreply, put_flash(socket, :error, "Offer not found")}

      {offer, _rate} ->
        user_ip = socket.assigns[:user_ip] || "0.0.0.0"
        recipient = socket.assigns[:recipient]
        split_amount = socket.assigns.current_scope.user.me_file.split_amount

        case Qlarius.Sponster.Ads.Video.create_video_ad_event(
               offer,
               recipient,
               split_amount,
               user_ip
             ) do
          {:ok, _ad_event} ->
            completed_ids = [offer_id | socket.assigns.completed_video_offers]

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

  def handle_event("video_collect_timeout", _params, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, true)
     |> assign(:show_collection_drawer, true)}
  end

  def handle_event("replay_video", _params, socket) do
    socket = assign(socket, :drawer_closing, true)
    Process.send_after(self(), :finish_closing_drawer, 300)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:finish_closing_drawer, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)
     |> assign(:show_collection_drawer, false)
     |> assign(:drawer_closing, false)
     |> push_event("replay-video", %{})}
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
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:me_file_offers_updated, _me_file_id}, socket) do
    me_file = socket.assigns.current_scope.user.me_file
    ads_count = Qlarius.YouData.MeFiles.MeFile.ad_offer_count(me_file)
    three_tap_ad_count = Qlarius.YouData.MeFiles.MeFile.three_tap_ad_offer_count(me_file)
    video_ad_count = Qlarius.YouData.MeFiles.MeFile.video_ad_offer_count(me_file)
    offered_amount = Qlarius.Sponster.Offers.total_active_offer_amount(me_file)

    current_scope =
      socket.assigns.current_scope
      |> Map.put(:ads_count, ads_count)
      |> Map.put(:three_tap_ad_count, three_tap_ad_count)
      |> Map.put(:video_ad_count, video_ad_count)
      |> Map.put(:offered_amount, offered_amount)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({:me_file_pending_referral_clicks_updated, pending_clicks_count}, socket) do
    current_scope =
      Map.put(socket.assigns.current_scope, :pending_referral_clicks_count, pending_clicks_count)

    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tipjar_container {assigns}>
      <%= if @show_video_player && @current_video_offer do %>
        <div
          class="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4"
          phx-click="close_video_player"
        >
          <div
            class="bg-base-100 rounded-lg max-w-2xl w-full max-h-[90vh] overflow-auto"
            phx-click={JS.exec("phx-click", to: "#video-player-content")}
          >
            <div id="video-player-content" class="p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-2xl font-bold">
                  {@current_video_offer.media_run.media_piece.ad_category.ad_category_name}
                </h2>
                <button class="btn btn-sm btn-circle btn-ghost" phx-click="close_video_player">
                  ✕
                </button>
              </div>

              <.video_player
                current_video_offer={@current_video_offer}
                video_payment_collected={@video_payment_collected}
              />
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_ad_type_tabs do %>
        <.ad_type_tabs
          selected_ad_type={@selected_ad_type}
          three_tap_ad_count={@current_scope.three_tap_ad_count || 0}
          video_ad_count={@current_scope.video_ad_count || 0}
        />
      <% end %>

      <%= if @selected_ad_type == "three_tap" do %>
        <%= if !@loading && Enum.empty?(@active_offers) do %>
          <div class="text-center text-base-content/70 py-8">
            No 3-Tap ads available
          </div>
        <% else %>
          <div class="px-4 sm:px-0 max-w-3xl mx-auto">
            <.live_component
              module={QlariusWeb.ThreeTapStackComponent}
              id="three-tap-stack"
              active_offers={@active_offers}
              user_ip={@user_ip}
              current_scope={@current_scope}
              host_uri={@host_uri}
              recipient={@recipient}
            />
          </div>
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
            />
          </ul>
        <% end %>
      <% end %>

      <%= if @current_video_offer && @show_video_player do %>
        <.video_collection_drawer
          current_video_offer={@current_video_offer}
          show_collection_drawer={@show_collection_drawer && (@video_watched_complete || @video_payment_collected || @show_replay_button)}
          video_payment_collected={@video_payment_collected}
          show_replay_button={@show_replay_button}
          closing={@drawer_closing}
        />
      <% end %>
    </Layouts.tipjar_container>
    """
  end

  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
