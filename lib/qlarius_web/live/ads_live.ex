defmodule QlariusWeb.AdsLive do
  use QlariusWeb, :live_view

  # Commented out unused alias - MeFile not directly referenced
  # alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Offer
  # Commented out unused alias - Users not directly referenced
  # alias Qlarius.Accounts.Users
  # Commented out unused alias - User not directly referenced
  # alias Qlarius.Accounts.User
  # Commented out unused aliases - LedgerHeader/LedgerEntry not directly referenced
  # alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  # Commented out unused alias - AdEvent not directly referenced
  # alias Qlarius.Sponster.AdEvent
  alias Qlarius.Repo
  # Commented out unused alias - Scope not directly referenced
  # alias Qlarius.Accounts.Scope
  # Commented out unused aliases - ThreeTap/MediaPiece/AdCategory not directly referenced
  # alias Qlarius.Sponster.Ads.{ThreeTap, MediaPiece, AdCategory}
  # Commented out unused alias - Component not directly referenced
  # alias Phoenix.Component
  alias Qlarius.Wallets
  alias Qlarius.Wallets.MeFileStatsBroadcaster
  # Commented out unused import - OfferHTML functions not used in this LiveView
  # import QlariusWeb.OfferHTML
  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.PWAHelpers

  on_mount {QlariusWeb.GetUserIP, :assign_ip}
  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @impl true
  def mount(%{"extension" => "true"} = params, _session, socket) do
    IO.puts("=== LIVEVIEW MOUNTING IN EXTENSION CONTEXT ===")
    IO.puts("Params: #{inspect(params)}")

    # Add a visual indicator in the page
    socket = assign(socket, :extension_mode, true)

    socket = assign(socket, :current_path, "/ads")

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    socket =
      socket
      |> assign(:active_offers, [])
      |> assign(:video_offers, [])
      |> assign(:selected_ad_type, "three_tap")
      |> assign(:loading, true)
      |> assign(:host_uri, host_uri)
      |> assign(:show_video_player, false)
      |> assign(:current_video_offer, nil)
      |> assign(:video_watched_complete, false)
      |> assign(:show_replay_button, false)
      |> assign(:video_payment_collected, false)
      |> assign(:completed_video_offers, [])

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
  def mount(_params, session, socket) do
    IO.puts("=== LIVEVIEW MOUNTING IN NORMAL CONTEXT ===")
    socket = assign(socket, :current_path, "/ads")

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    socket =
      socket
      |> assign(:active_offers, [])
      |> assign(:video_offers, [])
      |> assign(:selected_ad_type, "three_tap")
      |> assign(:loading, true)
      |> assign(:host_uri, host_uri)
      |> assign(:title, "Ads")
      |> assign(:show_video_player, false)
      |> assign(:current_video_offer, nil)
      |> assign(:video_watched_complete, false)
      |> assign(:show_replay_button, false)
      |> assign(:video_payment_collected, false)
      |> assign(:completed_video_offers, [])
      |> init_pwa_assigns(session)

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
  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("toggle_sidebar", %{"state" => state}, socket) do
    js =
      if state == "on" do
        %JS{}
        |> JS.add_class("translate-x-0", to: "#sponster-sidebar")
        |> JS.remove_class("-translate-x-full", to: "#sponster-sidebar")
        |> JS.remove_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")
      else
        %JS{}
        |> JS.remove_class("translate-x-0", to: "#sponster-sidebar")
        |> JS.add_class("-translate-x-full", to: "#sponster-sidebar")
        |> JS.add_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")
      end

    {:noreply, push_event(socket, "js", js)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    # Handle click-away event
    js =
      %JS{}
      |> JS.remove_class("translate-x-0", to: "#sponster-sidebar")
      |> JS.add_class("-translate-x-full", to: "#sponster-sidebar")
      |> JS.add_class("opacity-0 pointer-events-none", to: "#sponster-sidebar-bg")

    {:noreply, push_event(socket, "js", js)}
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
     |> assign(:show_replay_button, false)}
  end

  def handle_event("close_video_player", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_player, false)
     |> assign(:current_video_offer, nil)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)}
  end

  def handle_event("close_slide_over", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_player, false)
     |> assign(:current_video_offer, nil)
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
     |> assign(:video_payment_collected, false)}
  end

  def handle_event("video_watched_complete", _params, socket) do
    if socket.assigns.video_payment_collected do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:video_watched_complete, true)
       |> assign(:show_replay_button, false)}
    end
  end

  def handle_event("collect_video_payment", %{"offer_id" => offer_id}, socket) do
    IO.puts("=== COLLECT VIDEO PAYMENT EVENT RECEIVED ===")
    IO.inspect(offer_id, label: "Offer ID")

    offer_id = String.to_integer(offer_id)

    case Enum.find(socket.assigns.video_offers, fn {o, _r} -> o.id == offer_id end) do
      nil ->
        IO.puts("ERROR: Offer not found in video_offers list")
        {:noreply, put_flash(socket, :error, "Offer not found")}

      {offer, _rate} ->
        IO.puts("Found offer, creating ad event...")
        user_ip = socket.assigns[:user_ip] || "0.0.0.0"

        case Qlarius.Sponster.Ads.Video.create_video_ad_event(offer, nil, 0, user_ip) do
          {:ok, _ad_event} ->
            IO.puts("✅ Ad event created successfully!")
            completed_ids = [offer_id | socket.assigns.completed_video_offers]
            {:noreply,
             socket
             |> assign(:video_watched_complete, false)
             |> assign(:show_replay_button, true)
             |> assign(:video_payment_collected, true)
             |> assign(:completed_video_offers, completed_ids)
             |> put_flash(:info, "Payment collected!")}

          {:error, reason} ->
            IO.puts("❌ Failed to create ad event")
            IO.inspect(reason, label: "Error reason")
            {:noreply, put_flash(socket, :error, "Failed to collect payment")}
        end
    end
  end

  def handle_event("video_collect_timeout", _params, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, true)}
  end

  def handle_event("replay_video", _params, socket) do
    {:noreply,
     socket
     |> assign(:video_watched_complete, false)
     |> assign(:show_replay_button, false)
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
    {:noreply, assign(socket, :current_scope, current_scope)}
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
  def render(assigns) do
    ~H"""
    <div id="ads-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile
        {assigns}
        slide_over_active={@show_video_player && @current_video_offer}
        slide_over_title={
          (@current_video_offer &&
             @current_video_offer.media_run.media_piece.ad_category.ad_category_name) || "Video Ad"
        }
        slide_over_show_wallet={true}
      >
        <:slide_over_content>
          <%= if @current_video_offer do %>
            <div class="p-4">
              <div class="mb-4">
                <video
                  id="video-player"
                  phx-hook="VideoPlayer"
                  data-payment-collected={@video_payment_collected}
                  class="w-full rounded-lg"
                  controls
                  src={
                    QlariusWeb.Uploaders.AdVideo.url(
                      {@current_video_offer.media_run.media_piece.video_file,
                       @current_video_offer.media_run.media_piece},
                      :original
                    )
                  }
                >
                </video>
              </div>

              <%= if !@video_payment_collected do %>
                <style>
                  /* Hide video timeline/scrubber before payment collection */
                  #video-player::-webkit-media-controls-timeline {
                    display: none !important;
                  }
                  #video-player::-webkit-media-controls-current-time-display {
                    display: none !important;
                  }
                  #video-player::-webkit-media-controls-time-remaining-display {
                    display: none !important;
                  }
                </style>
              <% end %>

              <%= if @video_watched_complete && !@show_replay_button do %>
                <style>
                  @keyframes subtle-wiggle {
                    0%, 100% { transform: translateX(0px) translateY(-50%); }
                    25% { transform: translateX(2px) translateY(-50%); }
                    75% { transform: translateX(-2px) translateY(-50%); }
                  }
                  #slide-to-collect-handle.wiggle {
                    animation: subtle-wiggle 0.8s ease-in-out infinite;
                  }
                </style>
                <div class="mt-6 px-4">
                  <div
                    id="slide-to-collect"
                    phx-hook="SlideToCollect"
                    data-offer-id={@current_video_offer.id}
                    data-amount={@current_video_offer.offer_amt}
                    class="relative max-w-xs mx-auto"
                  >
                    <div class="text-center mb-4">
                      <div class="text-2xl font-bold text-primary">
                        Collect ${Decimal.round(@current_video_offer.offer_amt, 2)}
                      </div>
                      <div class="text-sm text-base-content/60 mt-1">
                        Slide to collect in <span id="slide-to-collect-countdown">7</span>s
                      </div>
                    </div>

                    <div
                      id="slide-to-collect-slider"
                      class="relative h-20 bg-base-200 rounded-full overflow-hidden"
                    >
                      <div
                        id="slide-to-collect-progress"
                        class="absolute left-0 top-0 h-full bg-error/20 transition-all duration-1000 ease-linear"
                        style="width: 0%"
                      >
                      </div>

                      <div
                        id="slide-to-collect-handle"
                        class="wiggle absolute left-1 top-1/2 h-16 w-16 bg-primary rounded-full flex items-center justify-center cursor-grab active:cursor-grabbing shadow-lg"
                        style="transform: translateX(0px) translateY(-50%)"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-7 w-7 text-primary-content"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 5l7 7-7 7"
                          />
                        </svg>
                      </div>

                      <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
                        <span class="text-base-content/40 font-semibold">Slide to collect</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @video_payment_collected do %>
                <div class="mt-6 px-4">
                  <div class="bg-sponster-100 dark:bg-sponster-900/20 border border-sponster-300 rounded-lg p-6 text-center">
                    <div class="text-green-600 dark:text-green-400 mb-3">
                      <.icon name="hero-check-circle" class="w-12 h-12 mx-auto" />
                    </div>
                    <div class="text-xl font-bold text-sponster-600 dark:text-sponster-300 mb-2">
                      ${Decimal.round(@current_video_offer.offer_amt, 2)} Added to Wallet!
                    </div>
                    <div class="text-sm text-base-content/70">
                      Your payment has been collected
                    </div>
                  </div>

                  <div class="text-center mt-4">
                    <button class="btn btn-outline btn-lg" phx-click="replay_video">
                      <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
                      Replay Video (Unpaid)
                    </button>
                  </div>
                </div>
              <% end %>

              <%= if @show_replay_button && !@video_payment_collected do %>
                <div class="text-center mt-6 px-4">
                  <div class="bg-error/10 border border-error/30 rounded-lg p-4 mb-4">
                    <div class="text-sm text-base-content/70">
                      Time expired - watch again to collect
                    </div>
                  </div>
                  <button class="btn btn-primary btn-lg" phx-click="replay_video">
                    <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" />
                    Replay Video
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </:slide_over_content>

        <%= if @current_scope.three_tap_ad_count > 0 && @current_scope.video_ad_count > 0 do %>
          <div class="flex justify-center mt-2 mb-6">
            <div role="tablist" class="tabs tabs-boxed bg-base-200 p-1 rounded-lg gap-1">
              <a
                role="tab"
                class={
                  if @selected_ad_type == "three_tap",
                    do: "tab tab-active bg-base-100 rounded-md !border-1 !border-primary",
                    else: "tab !border-1 !border-transparent"
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
                    do: "tab tab-active bg-base-100 rounded-md !border-1 !border-primary",
                    else: "tab !border-1 !border-transparent"
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
                  <li
                    :for={{offer, rate} <- @video_offers}
                    class={[
                      "list-row transition-all duration-200 !rounded-none",
                      if(offer.id in @completed_video_offers,
                        do: "bg-base-300 cursor-default select-none",
                        else: "cursor-pointer hover:bg-base-300 dark:hover:!bg-base-100"
                      )
                    ]}
                    phx-click={if offer.id not in @completed_video_offers, do: "open_video_ad"}
                    phx-value-offer_id={offer.id}
                  >
                    <%= if offer.id in @completed_video_offers do %>
                      <%!-- Completed state --%>
                      <div class="flex flex-col items-start justify-start mr-1">
                        <span class="inline-flex items-center justify-center rounded-full w-8 h-8 !bg-green-200 dark:!bg-green-800">
                          <.icon name="hero-check" class="h-5 w-5 text-green-600 dark:text-green-300" />
                        </span>
                      </div>
                      <div class="list-col-grow">
                        <div class="text-sm font-semibold text-base-content/70 mb-2">
                          Attention Paid™
                        </div>
                        <div class="text-xs text-base-content/50">
                          Collected: <span class="font-semibold">${Decimal.round(offer.offer_amt || Decimal.new("0"), 2)}</span>
                        </div>
                      </div>
                      <div class="flex items-center">
                        <div class="text-base-content/30">
                          <.icon name="hero-check-circle" class="w-6 h-6" />
                        </div>
                      </div>
                    <% else %>
                      <%!-- Available state --%>
                      <div class="flex flex-col items-start justify-start mr-1">
                        <span class="inline-flex items-center justify-center rounded-full w-8 h-8 !bg-sponster-200 dark:!bg-sponster-800">
                          <.icon name="hero-play" class="h-5 w-5 text-base-content" />
                        </span>
                      </div>
                      <div class="list-col-grow">
                        <div class="text-2xl font-bold mb-2">
                          ${Decimal.round(offer.offer_amt || Decimal.new("0"), 2)}
                        </div>
                        <div class="mb-2 text-base-content/50 text-base">
                          {offer.media_run.media_piece.ad_category.ad_category_name}
                        </div>
                        <div class="flex items-center gap-2">
                          <%= if offer.matching_tags_snapshot && String.contains?(String.downcase(inspect(offer.matching_tags_snapshot)), "zip code") do %>
                            <div class="text-blue-400">
                              <.icon name="hero-map-pin-solid" class="w-4 h-4" />
                            </div>
                          <% end %>
                          <div class="text-base-content/50 text-sm">
                            {offer.media_run.media_piece.duration}s · ${Decimal.round(rate, 3)}/sec
                          </div>
                        </div>
                      </div>
                      <div class="flex items-center">
                        <div class="text-green-600">
                          <.icon name="hero-chevron-double-right" class="w-6 h-6" />
                        </div>
                      </div>
                    <% end %>
                  </li>
                </ul>
            <% end %>
          <% end %>
      </Layouts.mobile>
    </div>
    """
  end

  # Standard LiveView terminate callback - parameters not used but required by protocol
  @impl true
  def terminate(_reason, _socket) do
    :ok
  end
end
