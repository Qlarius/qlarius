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

    socket =
      socket
      |> assign(:page_title, "Sponster Announcer")

    if connected?(socket) do
      MeFileBalanceBroadcaster.subscribe_to_me_file_balance(socket.assigns.current_scope.user.me_file.id)
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

  @impl true
  def render(assigns) do
    ~H"""

    <div id="ydadget_announcer_float_bottom_background_layer">
      <div class="spin-bounce-background-item">
        <div class="spinner">
          <img src={~p"/images/sponster_us_quarter.png"} />
        </div>
      </div>
    </div>


    <div class="sponster-announcer-bottom-float-strip"></div>
    <div
      class="sponster-announcer-bottom-float-content-container"
      style="height:50px; padding: 0 10px; display:flex; flex-direction:row; justify-content:space-between; align-items:center; background: #fff;"
    >
      <div class="sponster-announcer-logo-container">
        <%!-- <img src="/images/Sponster_logo_color_horiz.svg" alt="Sponster logo" class="h-8 w-auto" /> --%>
      </div>

      <div style="width: 240px; position:relative;display:flex; flex-direction:row; justify-content:space-between; align-items:center; background: #F0F2F4; border-radius: 8px;">
        <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
          <div
            id="announcer-wallet-amount"
            style="color: #292929; font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
          >
            ${@current_scope.wallet_balance}
          </div>
          <div style="color: #797979; font-size: 8px;  font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;">
            WALLET
          </div>
        </div>
        <div style="width: 0px; height: 20px; border-left: 1px solid #cbcbcb"></div>
        <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
          <div
            id="announcer-ad-count"
            style="color: #252529; font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
          >
            {@current_scope.ads_count}
          </div>
          <div style="color: #6F7479; font-size: 8px; font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;">
            ADS
          </div>
        </div>
        <div style="width: 0px; height: 20px; border-left: 1px solid #cbcbcb"></div>
        <div style="display:flex; flex-direction:column; justify-content:center; align-items:center; width:100%; padding: 6px 0;">
          <div
            id="announcer-offered-amount"
            style="color: #252529; font-size: 16px; line-height:16px; font-weight: 600; letter-spacing: 0.40px; word-wrap: break-word"
          >
            ${@current_scope.offered_amount}
          </div>
          <div style="color: #6F7479; font-size: 8px; font-weight: 500; letter-spacing: 0.20px; word-wrap: break-word; line-height:10px;">
            OFFERED
          </div>
        </div>
      </div>

      <div
        style="width:96px; position:relative; display:flex; flex-direction:row; justify-content:space-between; align-items:center; border-radius: 9999px; border: 1.50px #252529 solid; padding: 4px 12px; cursor: pointer;"
        onclick="parent.postMessage('open_widget','*');self.toggleAnnouncerElements();"
      >
        <div
          id="ydadget_announcer_toggle_button_text"
          style="margin-right: 6px; color: #252529; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.32px; word-wrap: break-word"
        >
          SHOW
        </div>
          <span id="ydadget_announcer_toggle_icon" class="hero-chevron-double-up all-animate" style="color:#0A8F65;"></span>
      </div>
    </div>

    <script>
      var announcerToggleIcon = document.getElementById("ydadget_announcer_toggle_icon");
      var announcerToggleButtonText = document.getElementById("ydadget_announcer_toggle_button_text");
      var announcerWalletAmount = document.getElementById("announcer-wallet-amount");
      var announcerAdCount = document.getElementById("announcer-ad-count");
      var announcerOfferedAmount = document.getElementById("announcer-offered-amount");
      var currentMode = "open";

      function toggleAnnouncerElements() {
        if (currentMode == "open") {
          if (announcerToggleIcon) { announcerToggleIcon.style.transform = "rotate(180deg)"; }
          if (announcerToggleButtonText) { announcerToggleButtonText.textContent = "HIDE"; }
          currentMode = "closed";
        } else {
          if (announcerToggleIcon) { announcerToggleIcon.style.transform = "rotate(0deg)"; }
          if (announcerToggleButtonText) { announcerToggleButtonText.textContent = "SHOW"; }
          currentMode = "open";
        }
      }
    </script>

    <Layouts.debug_assigns {assigns} />
    """
  end
end
