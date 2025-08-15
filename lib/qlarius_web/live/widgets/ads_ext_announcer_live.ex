defmodule QlariusWeb.Widgets.AdsExtAnnouncerLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts.Users
  alias Qlarius.Sponster
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Accounts.User
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Wallets.MeFileBalanceBroadcaster
  alias Qlarius.Repo
  alias Qlarius.Accounts.Scope
  alias Phoenix.Component
  import Ecto.Query, except: [update: 2, update: 3]
  import QlariusWeb.Layouts
  import Jason

  @recruiter_mode true

  on_mount {QlariusWeb.GetUserIP, :assign_ip}

  @impl true
  def mount(params, session, socket) do
    # Load initial data during first mount
    user = socket.assigns.current_scope.user
    current_scope = socket.assigns.current_scope

    host_uri =
      case Phoenix.LiveView.get_connect_info(socket, :uri) do
        nil -> URI.parse("http://localhost")
        uri -> uri
      end

    lg_slides = [
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/DontReadThis_640.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/LifeSponsored_640.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/SellYourAttention_640.png"
      }
    ]

    sm_slides = [
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/DontReadThisA_280.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/DontReadThisB_280.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/SellYourAttention_280.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/LifeSponsoredA_280.png"
      },
      %{
        imgSrc:
          "https://qlarius-app-shared-dev-demo.s3.us-east-1.amazonaws.com/uploads/recruiter_banners/LifeSponsoredB_280.png"
      }
    ]

    socket =
      socket
      |> assign(:page_title, "Sponster Announcer")
      |> assign(:recruiter_mode, @recruiter_mode)
      |> assign(:lg_slides, lg_slides)
      |> assign(:sm_slides, sm_slides)

    if connected?(socket) do
      MeFileBalanceBroadcaster.subscribe_to_me_file_balance(
        socket.assigns.current_scope.user.me_file.id
      )

      {:ok, socket}
    else
      {:ok, socket}
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:refresh_wallet_balance, me_file_id}, socket) do
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

  defp slider_data(slides) do
    """
    {
      autoplayIntervalTime: 4000,
      slides: #{Jason.encode!(slides)},
      currentSlideIndex: 1,
      isPaused: false,
      autoplayInterval: null,
      isTransitioning: false,
      previous() {
        if (this.currentSlideIndex > 1) {
          this.currentSlideIndex = this.currentSlideIndex - 1
        } else {
          this.currentSlideIndex = this.slides.length
        }
      },
      next() {
        if (this.currentSlideIndex < this.slides.length) {
          this.currentSlideIndex = this.currentSlideIndex + 1
        } else {
          this.currentSlideIndex = 1
        }
      },
      autoplay() {
        this.autoplayInterval = setInterval(() => {
          if (!this.isPaused && !this.isTransitioning) {
            this.next()
          }
        }, this.autoplayIntervalTime)
      },
      setAutoplayInterval(newIntervalTime) {
        clearInterval(this.autoplayInterval)
        this.autoplayIntervalTime = newIntervalTime
        this.autoplay()
      }
    }
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="ydadget_announcer_float_bottom_background_layer">
      <%= if @recruiter_mode do %>
        <div class="spin-bounce-background-item">
          <div class="spinner">
            <img src={~p"/images/sponster_us_quarter.png"} />
          </div>
        </div>
      <% end %>
    </div>

    <div class="sponster-announcer-bottom-float-strip !bg-base-100"></div>

    <div class="sponster-announcer-bottom-float-content-container bg-base-100">
      <%= if @recruiter_mode do %>
        <div id="sponster_recruiter_slider_lg">
          <div
            x-data={slider_data(@lg_slides)}
            x-init="autoplay"
            class="relative w-full overflow-hidden"
          >
            
    <!-- slides -->
            <div class="relative min-h-[70px] w-full">
              <template x-for="(slide, index) in slides">
                <div
                  x-cloak
                  x-show="currentSlideIndex == index + 1"
                  class="absolute inset-0"
                  x-transition:enter="transition ease-out duration-1000"
                  x-transition:enter-start="opacity-0"
                  x-transition:enter-end="opacity-100"
                  x-transition:leave="transition ease-in duration-1000"
                  x-transition:leave-start="opacity-100"
                  x-transition:leave-end="opacity-0"
                >
                  <img
                    class="absolute w-full h-full inset-0 object-cover text-on-surface dark:text-on-surface-dark"
                    x-bind:src="slide.imgSrc"
                    x-bind:alt="slide.imgAlt"
                  />
                </div>
              </template>
            </div>
          </div>
        </div>
        <div id="sponster_recruiter_slider_sm">
          <div
            x-data={slider_data(@sm_slides)}
            x-init="autoplay"
            class="relative w-full overflow-hidden"
          >
            <div class="relative min-h-[70px] w-full">
              <template x-for="(slide, index) in slides">
                <div
                  x-cloak
                  x-show="currentSlideIndex == index + 1"
                  class="absolute inset-0"
                  x-transition:enter="transition ease-out duration-1000"
                  x-transition:enter-start="opacity-0"
                  x-transition:enter-end="opacity-100"
                  x-transition:leave="transition ease-in duration-1000"
                  x-transition:leave-start="opacity-100"
                  x-transition:leave-end="opacity-0"
                >
                  <img
                    class="absolute w-full h-full inset-0 object-cover text-on-surface dark:text-on-surface-dark"
                    x-bind:src="slide.imgSrc"
                    x-bind:alt="slide.imgAlt"
                  />
                </div>
              </template>
            </div>
          </div>
        </div>
      <% else %>
        <div class="sponster-announcer-logo-container" />
        <div
          class="bg-base-200 shadow-[inset_0_0_2px_rgba(0,0,0,0.1)]"
          style="width: 240px; position:relative;display:flex; flex-direction:row; justify-content:space-between; align-items:center; border-radius: 8px;"
        >
          <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
            <div
              id="announcer-wallet-amount"
              class="text-base-content"
              style="font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
            >
              ${@current_scope.wallet_balance}
            </div>
            <div
              class="text-base-content/40"
              style="font-size: 8px;  font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;"
            >
              WALLET
            </div>
          </div>
          <div style="width: 0px; height: 20px; border-left: 1px solid #cbcbcb"></div>
          <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
            <div
              id="announcer-ad-count"
              class="text-base-content"
              style="font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
            >
              {@current_scope.ads_count}
            </div>
            <div
              class="text-base-content/40"
              style="font-size: 8px; font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;"
            >
              ADS
            </div>
          </div>
          <div style="width: 0px; height: 20px; border-left: 1px solid #cbcbcb"></div>
          <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
            <div
              id="announcer-offered-amount"
              class="text-base-content"
              style="font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
            >
              ${@current_scope.offered_amount}
            </div>
            <div
              class="text-base-content/40"
              style="font-size: 8px; font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;"
            >
              OFFERED
            </div>
          </div>
        </div>
      <% end %>
      <div
        style="width:96px; position:relative; display:flex; flex-direction:row; justify-content:space-between; align-items:center; border-radius: 9999px; padding: 4px 12px; cursor: pointer;"
        class="border-[1.5px] border-base-content/80"
        onclick="parent.postMessage('open_widget','*');self.toggleAnnouncerElements();"
      >
        <div
          id="ydadget_announcer_toggle_button_text"
          class="text-base-content"
          style="margin-right: 6px; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.32px; word-wrap: break-word"
        >
          {if @recruiter_mode, do: "INFO", else: "SHOW"}
        </div>
        <span
          id="ydadget_announcer_toggle_icon"
          class="hero-chevron-double-up all-animate bg-sponster-500"
        >
        </span>
      </div>
    </div>

    <script>
        var announcerToggleIcon = document.getElementById("ydadget_announcer_toggle_icon");
        var announcerToggleButtonText = document.getElementById("ydadget_announcer_toggle_button_text");
        var announcerWalletAmount = document.getElementById("announcer-wallet-amount");
        var announcerAdCount = document.getElementById("announcer-ad-count");
        var announcerOfferedAmount = document.getElementById("announcer-offered-amount");
        var currentMode = "open";
        var originalButtonText = announcerToggleButtonText ? announcerToggleButtonText.textContent : "SHOW";

        function toggleAnnouncerElements() {
          if (currentMode == "open") {
            if (announcerToggleIcon) { announcerToggleIcon.style.transform = "rotate(180deg)"; }
            if (announcerToggleButtonText) { announcerToggleButtonText.textContent = "HIDE"; }
            currentMode = "closed";
          } else {
            if (announcerToggleIcon) { announcerToggleIcon.style.transform = "rotate(0deg)"; }
            if (announcerToggleButtonText) { announcerToggleButtonText.textContent = originalButtonText; }
            currentMode = "open";
          }
        }

        document.addEventListener('alpine:init', () => {
          Alpine.data('carousel', (carouselData = {
              slides: [],
              intervalTime: 0,
          },) => ({
              slides: carouselData.slides,
              autoplayIntervalTime: carouselData.intervalTime,
              currentSlideIndex: 1,
              isPaused: false,
              autoplayInterval: null,
              isTransitioning: false,
              previous() {
                  if (this.isTransitioning) return;
                  this.isTransitioning = true;
                  if (this.currentSlideIndex > 1) {
                      this.currentSlideIndex = this.currentSlideIndex - 1
                  } else {
                      // If it's the first slide, go to the last slide
                      this.currentSlideIndex = this.slides.length
                  }
                  setTimeout(() => { this.isTransitioning = false; }, 1000);
              },
              next() {
                  if (this.isTransitioning) return;
                  this.isTransitioning = true;
                  if (this.currentSlideIndex < this.slides.length) {
                      this.currentSlideIndex = this.currentSlideIndex + 1
                  } else {
                      // If it's the last slide, go to the first slide
                      this.currentSlideIndex = 1
                  }
                  setTimeout(() => { this.isTransitioning = false; }, 1000);
              },
              autoplay() {
                  this.autoplayInterval = setInterval(() => {
                    console.log("autoplay")
                      if (! this.isPaused && !this.isTransitioning) {
                          this.next()
                      }
                  }, this.autoplayIntervalTime)
              },
              // Updates interval time
              setAutoplayIntervalTime(newIntervalTime) {
                  clearInterval(this.autoplayInterval)
                  this.autoplayIntervalTime = newIntervalTime
                  this.autoplay()
              },
          }))
      })
    </script>

    <Layouts.debug_assigns {assigns} />
    """
  end
end
