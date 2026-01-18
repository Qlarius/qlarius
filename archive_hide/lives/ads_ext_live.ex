defmodule QlariusWeb.AdsExtLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Sponster.Offers
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData
  alias Qlarius.Wallets

  import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Layouts

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @debug Mix.env() != :prod

  @impl true
  def mount(params, session, socket) do
    offers =
      socket.assigns.current_scope.user.id
      |> Offers.list_user_offers()
      |> Enum.map(fn offer ->
        # {offer, phase}. Phase is an integer between 0 and 3
        {offer, 0}
      end)

    socket =
      socket
      |> assign(:active_offers, offers)
      |> assign(:video_offers, [])
      |> assign(:selected_ad_type, "three_tap")
      |> assign(:loading, true)
      |> assign(:debug, @debug)
      |> assign(:page_title, "Sponster")
      |> assign(:show_video_player, false)
      |> assign(:current_video_offer, nil)
      |> assign(:video_watched_complete, false)
      |> assign(:show_replay_button, false)

    if connected?(socket) do
      send(self(), :load_offers)
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
        rate = Decimal.div(Decimal.new(offer.amount || "0"), Decimal.new(duration))
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
  def handle_info({:refresh_wallet_balance, me_file_id}, socket) do
    new_balance = Wallets.get_user_current_balance(socket.assigns.current_scope.user)
    current_scope = Map.put(socket.assigns.current_scope, :wallet_balance, new_balance)
    {:noreply, assign(socket, :current_scope, current_scope)}
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
     |> assign(:show_replay_button, false)}
  end

  @impl true
  def handle_event("close_video_player", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_player, false)
     |> assign(:current_video_offer, nil)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)}
  end

  @impl true
  def handle_event("video_watched_complete", _params, socket) do
    {:noreply, assign(socket, :video_watched_complete, true)}
  end

  @impl true
  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    offer_id = String.to_integer(offer_id)
    {offer, _rate} = Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end)

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
        {:noreply,
         socket
         |> assign(:show_video_player, false)
         |> assign(:current_video_offer, nil)
         |> assign(:video_watched_complete, false)
         |> assign(:show_replay_button, false)
         |> put_flash(:info, "Payment collected!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to collect payment")}
    end
  end

  @impl true
  def handle_event("video_collect_timeout", _params, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, true)}
  end

  @impl true
  def handle_event("replay_video", _params, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> push_event("replay-video", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.tipjar_container {assigns}>
      <div class="container mx-auto px-4 py-8 max-w-3xl my-[60px]">
        <div class="flex justify-center mb-6">
          <div role="tablist" class="tabs tabs-boxed bg-base-200 p-1 rounded-lg gap-1">
            <a
              role="tab"
              class={
                if @selected_ad_type == "three_tap",
                  do: "tab tab-active bg-base-100 rounded-md",
                  else: "tab"
              }
              phx-click="switch_ad_type"
              phx-value-type="three_tap"
            >
              3-Tap
              <%= if @current_scope.three_tap_ad_count && @current_scope.three_tap_ad_count > 0 do %>
                <span class="badge badge-sm ml-2 !bg-sponster-500 !text-white rounded-full !border-0">
                  {@current_scope.three_tap_ad_count}
                </span>
              <% end %>
            </a>
            <a
              role="tab"
              class={
                if @selected_ad_type == "video",
                  do: "tab tab-active bg-base-100 rounded-md",
                  else: "tab"
              }
              phx-click="switch_ad_type"
              phx-value-type="video"
            >
              Video
              <%= if @current_scope.video_ad_count && @current_scope.video_ad_count > 0 do %>
                <span class="badge badge-sm ml-2 !bg-sponster-500 !text-white rounded-full !border-0">
                  {@current_scope.video_ad_count}
                </span>
              <% end %>
            </a>
          </div>
        </div>

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
              me_file={@current_scope.user.me_file}
              user_ip={@user_ip}
              current_scope={@current_scope}
              host_uri={@host_uri}
              recipient={@recipient}
            />
          <% end %>
        <% else %>
          <%= if Enum.empty?(@video_offers) do %>
            <div class="text-center text-base-content/70 py-8">
              No video ads available
            </div>
          <% else %>
            <div class="space-y-2">
              <%= for {offer, rate} <- @video_offers do %>
                <div
                  class="flex items-center justify-between p-4 bg-base-200 rounded-lg hover:bg-base-300 cursor-pointer transition"
                  phx-click="open_video_ad"
                  phx-value-offer_id={offer.id}
                >
                  <div class="flex-1">
                    <div class="font-semibold text-base-content">
                      {offer.media_run.media_piece.ad_category.name}
                    </div>
                    <div class="text-sm text-base-content/60">
                      Duration: {offer.media_run.media_piece.duration}s
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="text-lg font-bold text-primary">
                      ${Decimal.round(Decimal.new(offer.amount || "0"), 2)}
                    </div>
                    <div class="text-xs text-base-content/60">
                      ${Decimal.round(rate, 3)}/sec
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>

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
                  {@current_video_offer.media_run.media_piece.ad_category.name}
                </h2>
                <button class="btn btn-sm btn-circle btn-ghost" phx-click="close_video_player">
                  ✕
                </button>
              </div>

              <div class="mb-4">
                <video
                  id="video-player"
                  phx-hook="VideoPlayer"
                  class="w-full rounded-lg"
                  controls
                  src={
                    QlariusWeb.Uploaders.AdVideo.url(
                      {@current_video_offer.media_run.media_piece.video_file, nil}
                    )
                  }
                >
                </video>
              </div>

              <%= if @video_watched_complete && !@show_replay_button do %>
                <div
                  id="slide-to-collect"
                  phx-hook="SlideToCollect"
                  data-offer-id={@current_video_offer.id}
                  data-amount={@current_video_offer.amount}
                  class="mt-4"
                >
                </div>
              <% end %>

              <%= if @show_replay_button do %>
                <div class="text-center mt-4">
                  <button class="btn btn-primary btn-lg" phx-click="replay_video">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-6 w-6 mr-2"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                      />
                    </svg>
                    Replay Video
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <pre :if={@debug} class="mt-8 p-4 bg-gray-100 rounded overflow-auto text-sm">
        <%= inspect(assigns, pretty: true) %>
      </pre>
    </Layouts.tipjar_container>
    """
  end

  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
