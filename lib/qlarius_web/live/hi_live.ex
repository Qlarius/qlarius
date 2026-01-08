defmodule QlariusWeb.HiLive do
  use QlariusWeb, :live_view

  def mount(_params, session, socket) do
    is_authenticated = !!socket.assigns[:current_scope]
    has_session_token = Map.get(session, "user_token") != nil

    socket =
      socket
      |> assign(:page_title, "Welcome to Qadabra")
      |> assign(:mode, :loading)
      |> assign(:is_mobile, false)
      |> assign(:is_authenticated, is_authenticated)
      |> assign(:has_session_token, has_session_token)
      |> assign(:device_type, :desktop)
      |> assign(:is_pwa, false)

    {:ok, socket}
  end

  def handle_event(
        "pwa_detected",
        %{"is_pwa" => is_pwa, "in_iframe" => in_iframe, "is_mobile" => is_mobile} = params,
        socket
      ) do
    # Get device type from JavaScript detection (more reliable than server-side)
    # Convert string to atom
    device_type =
      case Map.get(params, "device_type", "mobile_phone") do
        "ios_phone" -> :ios_phone
        "android_phone" -> :android_phone
        "desktop" -> :desktop
        _ -> :mobile_phone
      end

    mode = determine_mode(is_mobile, is_pwa, in_iframe, socket.assigns.is_authenticated)

    socket =
      socket
      |> assign(:mode, mode)
      |> assign(:is_pwa, is_pwa)
      |> assign(:in_iframe, in_iframe)
      |> assign(:is_mobile, is_mobile)
      |> assign(:device_type, device_type)

    {:noreply, socket}
  end

  def handle_event("show_install_guide", _params, socket) do
    {:noreply, assign(socket, :mode, :install)}
  end

  def handle_event("splash_complete", _params, socket) do
    cond do
      # Authenticated users: always go to home
      socket.assigns.is_authenticated ->
        {:noreply, push_navigate(socket, to: ~p"/home")}

      # PWA users (not authenticated): go to login or register
      socket.assigns.is_pwa && !socket.assigns.is_authenticated ->
        path = if socket.assigns.has_session_token, do: ~p"/login", else: ~p"/register"
        {:noreply, push_navigate(socket, to: path)}

      # Mobile browser (not PWA): show welcome carousel with Install button
      socket.assigns.is_mobile && !socket.assigns.is_pwa ->
        {:noreply, assign(socket, :mode, :welcome)}

      # Desktop: show welcome carousel with Login/Register buttons
      true ->
        {:noreply, assign(socket, :mode, :welcome)}
    end
  end

  defp determine_mode(is_mobile, _is_pwa, _in_iframe, is_authenticated) do
    cond do
      # Authenticated users always see splash before redirect
      is_authenticated ->
        :splash

      # Mobile users (not authenticated) start with splash
      is_mobile ->
        :splash

      # Desktop (not authenticated) goes straight to welcome
      true ->
        :welcome
    end
  end

  def render(assigns) do
    ~H"""
    <div phx-hook="HiPagePWADetect" id="hi-page">
      <%= if @mode == :loading do %>
        <%!-- Brief blank state while JS detects PWA --%>
        <div class="h-screen bg-base-100 dark:bg-base-300"></div>
      <% end %>

      <%= if @mode == :splash do %>
        <%!-- SPLASH MODE: Logo centered, 2 second display --%>
        <div
          phx-hook="HiPageSplash"
          id="hi-splash"
          class="h-screen flex items-center justify-center bg-base-100 dark:bg-base-300"
        >
          <img
            src="/images/qadabra_logo_squares_color.svg"
            alt="Qadabra"
            class="w-32 h-auto animate-pulse"
          />
        </div>
      <% end %>

      <%= if @mode == :install do %>
        <%!-- INSTALL MODE: Installation instructions --%>
        <div class="min-h-screen dark:bg-base-300 flex flex-col overflow-y-auto">
          <div class="flex-shrink-0 py-12 flex justify-center">
            <img
              src="/images/qadabra_full_gray_opt.svg"
              alt="Qadabra"
              class="h-12 md:h-16 w-auto"
            />
          </div>

          <div class="flex-1 flex items-center justify-center px-4 pb-24">
            <div class="w-full max-w-2xl">
              <%= if @device_type == :ios_phone do %>
                <.ios_install_guide />
              <% else %>
                <.android_install_guide />
              <% end %>

              <div class="mt-8 p-4 bg-base-200/50 dark:bg-base-200/50 rounded-xl text-center">
                <p class="text-sm text-base-content/60">
                  <.icon name="hero-information-circle" class="inline w-4 h-4" />
                  Installation takes less space than a photo and can be uninstalled anytime.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @mode == :welcome do %>
        <%!-- WELCOME MODE: Default carousel view --%>
        <div class="h-screen dark:bg-base-300 flex items-center justify-center pb-24 relative overflow-y-hidden">
          <div class="absolute top-12 left-0 right-0 flex justify-center z-10">
            <img
              src="/images/qadabra_full_gray_opt.svg"
              alt="Qadabra"
              class="h-12 md:h-16 w-auto"
            />
          </div>

          <div
            phx-hook="CarouselIndicators"
            id="carousel-container"
            class="w-full flex flex-col items-center justify-center overflow-hidden"
          >
            <.carousel />
          </div>

          <div class="fixed bottom-0 left-0 right-0 bg-base-100 dark:bg-base-300 border-t border-base-300 dark:border-base-content/20 py-4 px-8 backdrop-blur-sm bg-opacity-95">
            <div class="max-w-md mx-auto flex gap-3">
              <%= if @is_mobile do %>
                <%!-- Mobile users: Only show Install button, no Login/Register --%>
                <button
                  phx-click="show_install_guide"
                  class="btn btn-primary btn-lg w-full rounded-full text-lg normal-case"
                >
                  Install Qadabra
                </button>
              <% else %>
                <%!-- Desktop users: Show Login and Register --%>
                <.link
                  navigate={~p"/login"}
                  class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
                >
                  Login
                </.link>
                <.link
                  navigate={~p"/register"}
                  class="btn btn-primary btn-lg flex-1 rounded-full text-lg normal-case"
                >
                  Register
                </.link>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp install_guide_header(assigns) do
    ~H"""
    <div class="text-center mb-8">
      <div class="inline-flex items-center justify-center w-20 h-20 bg-primary/10 rounded-full mb-6">
        <.icon name="hero-device-phone-mobile" class="w-12 h-12 text-primary" />
      </div>

      <h1 class="text-4xl font-bold mb-4">3-Step Easy Install</h1>

      <p class="text-xl text-base-content/70 mb-4">
        Get the full mobile experience in the latest, lightest installation possible. No app store, no downloads, no waiting. Just a few clicks and you're ready to go.
      </p>

      <div class="flex flex-wrap justify-center gap-4 text-sm text-base-content/60">
        <div class="flex items-center gap-2">
          <.icon name="hero-lock-closed" class="w-4 h-4 text-primary" />
          <span>Full privacy & control</span>
        </div>
        <div class="flex items-center gap-2">
          <.icon name="hero-bell" class="w-4 h-4 text-primary" />
          <span>Push notifications</span>
        </div>
        <div class="flex items-center gap-2">
          <.icon name="hero-rocket-launch" class="w-4 h-4 text-primary" />
          <span>Instant updates</span>
        </div>
      </div>
    </div>
    """
  end

  defp ios_install_guide(assigns) do
    ~H"""
    <.install_guide_header />

    <div class="space-y-6">
      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            1
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap the Share button</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Look for it at the bottom of this browser window
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center gap-2">
              <span class="text-base-content/50"><.icon name="hero-ellipsis-horizontal-circle" class="w-6 h-6 text-base-content/50" /> +</span> <span class="text-base-content/70"><.icon name="hero-arrow-up-on-square" class="w-6 h-6 text-base-content" /></span>
              <span class="font-medium">
                Share
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            2
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Select "Add to Home Screen"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Scroll down in the share menu if you don't see it
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center gap-2">
              <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="3" y="3" width="18" height="18" rx="4" stroke="currentColor" stroke-width="2"/>
                <path d="M12 8v8M8 12h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
              </svg>
              <span class="font-medium">Add to Home Screen</span>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            3
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap "Add"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              The app will be added to your home screen.
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center justify-start">
              <svg class="h-7" viewBox="0 0 52 28" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="1" y="1" width="50" height="26" rx="13" fill="none" stroke="currentColor" stroke-width="1.5" opacity="0.3"/>
                <text x="26" y="18.5" font-family="system-ui, -apple-system, sans-serif" font-size="13" font-weight="600" fill="currentColor" text-anchor="middle">Add</text>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">That's it.</h3>
            <p class="text-sm text-base-content/70 mb-3">
               Find the new app icon on your home screen. Tap to launch!
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center gap-3">
              <img src="/images/qadabra_logo_squares_color.svg" class="w-12 h-12 rounded-xl" />
              <div>
                <p class="font-bold">Qadabra</p>
                <p class="text-xs text-base-content/60">Tap to launch</p>
              </div>
            </div>
          </div>
        </div>
      </div>



    </div>
    """
  end

  defp android_install_guide(assigns) do
    ~H"""
    <.install_guide_header />

    <div class="space-y-6">
      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            1
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap the menu (⋮)</h3>
            <p class="text-sm text-base-content/70">
              Usually in the top-right corner of Chrome
            </p>
          </div>
        </div>
      </div>

      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            2
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">
              Select "Install app" or "Add to Home screen"
            </h3>
            <p class="text-sm text-base-content/70 mb-3">
              The wording may vary by browser
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center gap-2">
              <.icon name="hero-arrow-down-tray" class="w-6 h-6 text-base-content" />
              <span class="font-medium">Install app</span>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-base-200 dark:bg-base-200 rounded-xl p-6">
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            3
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap "Install"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              The app will be added to your home screen. Tap the icon to launch!
            </p>
            <div class="bg-base-300 dark:bg-base-300 rounded-lg p-3 flex items-center gap-3">
              <img src="/images/qadabra_logo_squares_color.svg" class="w-12 h-12 rounded-xl" />
              <div>
                <p class="font-bold">Qadabra</p>
                <p class="text-xs text-base-content/60">Tap to launch</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp carousel(assigns) do
    ~H"""
    <div class="carousel carousel-center w-full max-w-7xl space-x-4 px-4">
      <div id="card1" class="carousel-item w-[85%] md:w-[300px]">
        <div class="card bg-base-200 shadow-xl w-full">
          <figure class="h-64 bg-gradient-to-br from-cyan-400 to-blue-600 relative overflow-hidden">
            <img
              src="/images/hi_sequence_wallet_light.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto dark:hidden"
            />
            <img
              src="/images/hi_sequence_wallet_dark.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto hidden dark:block"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title text-3xl font-bold">Claim your wallet.</h2>
            <p class="text-base-content/70">
              Your pre-funded wallet is ready for you. Set it up in seconds and use it to access the content and support the creators that matter to you. Media micropayments done right.
            </p>
            <div class="card-actions justify-center mt-4">
              <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="h-8 w-auto" />
            </div>
          </div>
        </div>
      </div>

      <div id="card2" class="carousel-item w-[85%] md:w-[300px]">
        <div class="card bg-base-200 shadow-xl w-full">
          <figure class="h-64 bg-gradient-to-br from-orange-400 to-red-600 relative overflow-hidden">
            <img
              src="/images/hi_sequence_media_light.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto dark:hidden"
            />
            <img
              src="/images/hi_sequence_media_dark.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto hidden dark:block"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title text-3xl font-bold">Buy your media.</h2>
            <p class="text-base-content/70">
              Pay pennies, not subscriptions. Instant access to only the content you actually want through simple micro-purchases. No commitments, just content.
            </p>
            <div class="card-actions justify-center mt-4">
              <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-8 w-auto" />
            </div>
          </div>
        </div>
      </div>

      <div id="card3" class="carousel-item w-[85%] md:w-[300px]">
        <div class="card bg-base-200 shadow-xl w-full">
          <figure class="h-64 bg-gradient-to-br from-green-400 to-emerald-600 relative overflow-hidden">
            <img
              src="/images/hi_sequence_ads_light.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto dark:hidden"
            />
            <img
              src="/images/hi_sequence_ads_dark.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto hidden dark:block"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title text-3xl font-bold">Sell your attention.</h2>
            <p class="text-base-content/70">
              You control your sponsorships. Choose which brands reach you. Capture revenue from ads to fuel your wallet. Your supply, your terms, your profit.
            </p>
            <div class="card-actions justify-center mt-4">
              <img src="/images/Sponster_logo_color_horiz.svg" alt="Sponster" class="h-8 w-auto" />
            </div>
          </div>
        </div>
      </div>

      <div id="card4" class="carousel-item w-[85%] md:w-[300px]">
        <div class="card bg-base-200 shadow-xl w-full">
          <figure class="h-64 bg-gradient-to-br from-purple-400 to-indigo-600 relative overflow-hidden">
            <img
              src="/images/hi_sequence_data_light.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto dark:hidden"
            />
            <img
              src="/images/hi_sequence_data_dark.png"
              alt=""
              class="absolute top-5 left-1/2 -translate-x-1/2 w-[60%] h-auto hidden dark:block"
            />
          </figure>
          <div class="card-body">
            <h2 class="card-title text-3xl font-bold">Own your data.</h2>
            <p class="text-base-content/70">
              Your data stays yours. Your MeFile™ matches and pulls sponsorships to you anonymously - no tracking, no reselling. Privacy that pays dividends.
            </p>
            <div class="card-actions justify-center mt-4">
              <img src="/images/YouData_logo_color_horiz.svg" alt="YouData" class="h-8 w-auto" />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-center gap-2 py-4">
      <a
        href="#card1"
        data-indicator="1"
        class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
      >
      </a>
      <a
        href="#card2"
        data-indicator="2"
        class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
      >
      </a>
      <a
        href="#card3"
        data-indicator="3"
        class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
      >
      </a>
      <a
        href="#card4"
        data-indicator="4"
        class="carousel-indicator w-3 h-3 rounded-full bg-base-content/30 hover:bg-base-content/50 transition-all duration-300"
      >
      </a>
    </div>
    """
  end
end
