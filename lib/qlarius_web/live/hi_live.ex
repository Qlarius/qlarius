defmodule QlariusWeb.HiLive do
  use QlariusWeb, :live_view

  import QlariusWeb.PWAHelpers
  import QlariusWeb.Components.SurfaceComponents

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  def mount(params, session, socket) do
    is_authenticated = !!socket.assigns[:current_scope]
    has_session_token = Map.get(session, "user_token") != nil

    # Capture referral code from URL params or session to pass to registration
    referral_code =
      Map.get(params, "ref") ||
        Map.get(params, "invite") ||
        Map.get(session, "referral_code") ||
        Map.get(session, "invitation_code")

    socket =
      socket
      |> assign(:page_title, "Welcome to Qadabra")
      |> assign(:mode, :loading)
      |> assign(:is_mobile, false)
      |> assign(:is_authenticated, is_authenticated)
      |> assign(:has_session_token, has_session_token)
      |> assign(:show_manifesto, false)
      |> assign(:referral_code, referral_code)
      |> assign(:mobile_use_browser, Map.get(session, "mobile_browser_ok", false))
      |> init_pwa_assigns(session)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    # Required for push_patch to work - we don't need to do anything here
    # as the URL update is just to ensure the ref code is in the address bar for PWA install
    {:noreply, socket}
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

    mode =
      determine_mode(
        is_mobile,
        is_pwa,
        in_iframe,
        socket.assigns.is_authenticated,
        socket.assigns.mobile_use_browser
      )

    socket =
      socket
      |> assign(:mode, mode)
      |> assign(:is_pwa, is_pwa)
      |> assign(:in_iframe, in_iframe)
      |> assign(:is_mobile, is_mobile)
      |> assign(:device_type, device_type)
      |> assign(
        :show_manifesto,
        show_manifesto?(
          mode,
          is_mobile,
          is_pwa,
          socket.assigns.is_authenticated,
          socket.assigns.mobile_use_browser
        )
      )

    socket =
      if mode == :mobile_choice do
        push_patch(socket, to: ~p"/hi")
      else
        socket
      end

    socket =
      cond do
        socket.assigns.is_authenticated && mode == :welcome ->
          push_navigate(socket, to: ~p"/home")

        is_mobile && !is_pwa && socket.assigns.mobile_use_browser &&
            socket.assigns.is_authenticated ->
          push_navigate(socket, to: ~p"/home")

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("go_to_connect", _params, socket) do
    {:noreply, redirect(socket, to: connect_path(socket.assigns.referral_code))}
  end

  def handle_event("show_install_guide", _params, socket) do
    # Keep a clean /hi URL in the address bar for iOS Add to Home Screen.
    # Referral codes stay in assigns/cookies, not the visible URL.
    {:noreply,
     socket
     |> assign(:mode, :install)
     |> push_patch(to: ~p"/hi")}
  end

  def handle_event("continue_in_browser", _params, socket) do
    socket = assign(socket, :mobile_use_browser, true)

    cond do
      socket.assigns.is_authenticated ->
        {:noreply, push_navigate(socket, to: ~p"/home")}

      socket.assigns.has_session_token ->
        {:noreply, redirect(socket, to: connect_path(socket.assigns.referral_code))}

      true ->
        {:noreply,
         socket
         |> assign(:mode, :welcome)
         |> assign(:show_manifesto, false)}
    end
  end

  def handle_event("dismiss_manifesto", _params, socket) do
    socket = assign(socket, :show_manifesto, false)

    socket =
      if mobile_install_choice?(socket) do
        assign(socket, :mode, :mobile_choice)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("referral_code_from_storage", %{"code" => code}, socket) do
    # Only update if we don't already have a referral code from URL/session
    if is_nil(socket.assigns.referral_code) or socket.assigns.referral_code == "" do
      {:noreply, assign(socket, :referral_code, code)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("splash_complete", _params, socket) do
    cond do
      # Authenticated PWA users: splash then home
      socket.assigns.is_authenticated && socket.assigns.is_pwa ->
        {:noreply, push_navigate(socket, to: ~p"/home")}

      # Authenticated users (desktop or otherwise): home — must run before has_session_token
      socket.assigns.is_authenticated ->
        {:noreply, push_navigate(socket, to: ~p"/home")}

      # Mobile browser (not PWA): manifesto first, then install vs browser choice
      socket.assigns.is_mobile && !socket.assigns.is_pwa ->
        {:noreply,
         socket
         |> assign(:mode, :welcome)
         |> assign(
           :show_manifesto,
           show_manifesto?(:welcome, true, false, false, socket.assigns.mobile_use_browser)
         )}

      # Saved credentials in desktop browser: go to Connect
      socket.assigns.has_session_token ->
        {:noreply, redirect(socket, to: connect_path(socket.assigns.referral_code))}

      # PWA users (not authenticated): Connect (AuthSheet phone → branch)
      socket.assigns.is_pwa ->
        {:noreply, push_navigate(socket, to: connect_path(socket.assigns.referral_code))}

      # Desktop: show welcome carousel with Connect CTA
      true ->
        {:noreply,
         socket
         |> assign(:mode, :welcome)
         |> assign(:show_manifesto, true)}
    end
  end

  defp connect_path(nil), do: ~p"/connect"
  defp connect_path(""), do: ~p"/connect"
  defp connect_path(code), do: ~p"/connect?ref=#{code}"

  defp store_mobile_browser_ok_click do
    %JS{}
    |> JS.dispatch("qlarius:store-mobile-browser-ok", to: "#hi-page")
    |> JS.push("continue_in_browser")
  end

  defp mobile_install_choice?(socket) do
    socket.assigns.is_mobile && !socket.assigns.is_pwa && !socket.assigns.mobile_use_browser &&
      !socket.assigns.is_authenticated
  end

  # Manifesto is for first-time, non-authenticated welcome only (no fade — omit from DOM when false).
  defp show_manifesto?(:welcome, true, false, false, false), do: true
  defp show_manifesto?(:welcome, false, _, false, _), do: true
  defp show_manifesto?(_, _, _, _, _), do: false

  defp determine_mode(is_mobile, is_pwa, _in_iframe, is_authenticated, mobile_use_browser) do
    cond do
      # Non-authenticated mobile browser: manifesto first (then install vs browser choice)
      is_mobile && !is_pwa && !is_authenticated ->
        :welcome

      # Authenticated mobile browser without PWA: install vs browser choice
      is_mobile && !is_pwa && !mobile_use_browser ->
        :mobile_choice

      # Authenticated mobile with prior "continue in browser" choice
      is_mobile && !is_pwa ->
        :welcome

      # Authenticated PWA: brief splash before home
      is_authenticated && is_pwa ->
        :splash

      # Authenticated desktop browser: welcome carousel (avoid splash → login → / loop)
      is_authenticated ->
        :welcome

      # Mobile PWA (not authenticated): splash before register
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
        <div class="page-canvas h-screen"></div>
      <% end %>

      <%= if @mode == :splash do %>
        <%!-- SPLASH MODE: Logo centered, 2 second display --%>
        <div
          phx-hook="HiPageSplash"
          id="hi-splash"
          class="page-canvas h-screen flex items-center justify-center"
        >
          <img
            src="/images/qadabra_logo_squares_color.svg"
            alt="Qadabra"
            class="w-32 h-auto animate-pulse"
          />
        </div>
      <% end %>

      <%= if @mode == :mobile_choice do %>
        <%!-- MOBILE CHOICE: Install as app vs continue in browser --%>
        <div class="page-canvas min-h-screen flex flex-col overflow-y-auto">
          <div class="flex-shrink-0 py-8 md:py-12 flex justify-center">
            <img
              src="/images/qadabra_full_gray_opt.svg"
              alt="Qadabra"
              class="h-12 md:h-16 w-auto"
            />
          </div>

          <div class="flex-1 flex items-center justify-center px-4 pb-12">
            <.surface_panel class="w-full max-w-md">
              <div class="space-y-6 text-center">
                <div class="flex justify-center">
                  <div class="flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full">
                    <.icon name="hero-device-phone-mobile" class="w-9 h-9 text-primary" />
                  </div>
                </div>

                <div>
                  <h1 class="text-2xl font-bold mb-2">Welcome to Qadabra</h1>
                  <p class="text-base text-base-content/70">
                    Install for the best experience, or sign in from your mobile browser.
                  </p>
                </div>

                <div class="flex flex-col gap-3">
                  <button
                    type="button"
                    phx-click="show_install_guide"
                    class="btn btn-primary btn-lg w-full rounded-full text-lg normal-case"
                  >
                    Install as app
                  </button>
                  <button
                    type="button"
                    phx-click={store_mobile_browser_ok_click()}
                    class="btn btn-outline btn-lg w-full rounded-full text-lg normal-case"
                  >
                    Continue in browser
                  </button>
                </div>
              </div>
            </.surface_panel>
          </div>
        </div>
      <% end %>

      <%= if @mode == :install do %>
        <%!-- INSTALL MODE: Installation instructions --%>
        <div class="page-canvas min-h-screen flex flex-col overflow-y-auto">
          <%!-- Logo spacer --%>
          <div class="flex-shrink-0 py-8 md:py-12 flex justify-center">
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

              <p class="mt-8 text-center text-sm text-base-content/60">
                <.icon name="hero-information-circle" class="inline w-4 h-4" />
                Installation takes less space than a photo and can be uninstalled anytime.
              </p>

              <p class="mt-6 text-center">
                <button
                  type="button"
                  phx-click={store_mobile_browser_ok_click()}
                  class="link link-hover text-sm text-base-content/60"
                >
                  Continue in browser instead
                </button>
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @mode == :welcome do %>
        <%= if @show_manifesto do %>
          <%!-- MANIFESTO OVERLAY (first-time non-authenticated welcome only) --%>
          <div class="fixed inset-0 z-50 page-canvas">
            <div class="absolute inset-4 border-10 border-dashed border-primary rounded-3xl animate-pulse">
            </div>

            <button
              phx-click="dismiss_manifesto"
              class="absolute top-12 right-12 z-10 btn btn-ghost btn-circle btn-sm"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-9 h-9 text-base-content/50" />
            </button>

            <div class="absolute inset-0 flex flex-col items-center justify-center px-12 text-center">
              <div class="max-w-sm space-y-6">
                <img
                  src="/images/qadabra_logo_squares_color.svg"
                  alt="Qadabra"
                  class="w-20 h-auto mx-auto mb-4"
                />

                <p class="text-2xl text-content-base">
                  This screen belongs to you.
                </p>

                <p class="text-2xl">
                  You bought it. <br />You pay the monthly bill.
                </p>

                <p class="text-2xl">
                  If anyone sells ad space here,
                  <span class="block mt-2 text-4xl font-extrabold leading-tight">
                    it should be you.
                  </span>
                </p>

                <div class="pt-8">
                  <button
                    phx-click="dismiss_manifesto"
                    class="btn btn-primary btn-lg rounded-full text-lg normal-case px-8"
                  >
                    Agreed. Let's go!
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- WELCOME MODE: Default carousel view --%>
        <div class="page-canvas h-screen flex flex-col relative overflow-y-hidden">
          <%!-- Logo spacer - ensures carousel doesn't overlap --%>
          <div class="flex-shrink-0 py-8 md:py-12 flex justify-center">
            <img
              src="/images/qadabra_full_gray_opt.svg"
              alt="Qadabra"
              class="h-12 md:h-16 w-auto"
            />
          </div>

          <%!-- Carousel container - can shrink if needed --%>
          <div
            phx-hook="CarouselIndicators"
            id="carousel-container"
            class="flex-1 min-h-0 w-full flex flex-col items-center justify-center overflow-hidden pb-24"
          >
            <.carousel />
          </div>

          <div class="fixed bottom-0 left-0 right-0 z-40 border-t border-base-300/80 dark:border-base-content/15 bg-base-200/95 dark:bg-base-300/95 py-4 px-8 backdrop-blur-sm">
            <div class="max-w-md mx-auto flex gap-3">
              <%= cond do %>
                <% @is_authenticated -> %>
                  <.link
                    href={~p"/home"}
                    class="btn btn-primary btn-lg w-full rounded-full text-lg normal-case"
                  >
                    Go to Home
                  </.link>
                <% @is_mobile && !@mobile_use_browser -> %>
                  <button
                    type="button"
                    phx-click="show_install_guide"
                    class="btn btn-primary btn-lg w-full rounded-full text-lg normal-case"
                  >
                    Install Qadabra
                  </button>
                <% true -> %>
                  <button
                    type="button"
                    phx-click="go_to_connect"
                    class="btn btn-primary btn-lg w-full rounded-full text-lg normal-case"
                  >
                    Connect
                  </button>
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
    <div class="mb-8">
      <div class="flex items-center justify-center gap-4 mb-4">
        <div class="flex-shrink-0 flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full">
          <.icon name="hero-device-phone-mobile" class="w-9 h-9 text-primary" />
        </div>
        <h1 class="text-3xl sm:text-4xl font-bold">3-Step Easy Install</h1>
      </div>

      <p class="text-base text-base-content/70 text-center mb-4">
        Get the full mobile experience in the latest, lightest installation possible. No app store, no downloads, no waiting. Just 3 taps and you're ready to go.
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
      <.surface_panel>
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            1
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap the Share button</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Look for it at the bottom of this browser window
            </p>
            <div class="p-3 flex items-center gap-2 bg-base-300/70 dark:bg-white/5 rounded-lg">
              <span class="text-base-content/50">
                <.icon name="hero-ellipsis-horizontal-circle" class="w-6 h-6 text-base-content/50" />
                +
              </span>
              <span class="text-base-content/70">
                <.icon name="hero-arrow-up-on-square" class="w-6 h-6 text-base-content" />
              </span>
              <span class="font-medium">
                Share
              </span>
            </div>
          </div>
        </div>
      </.surface_panel>

      <.surface_panel>
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            2
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Select "Add to Home Screen"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Scroll down in the share menu if you don't see it
            </p>
            <div class="p-3 flex items-center gap-2 bg-base-300/70 dark:bg-white/5 rounded-lg">
              <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect
                  x="3"
                  y="3"
                  width="18"
                  height="18"
                  rx="4"
                  stroke="currentColor"
                  stroke-width="2"
                />
                <path
                  d="M12 8v8M8 12h8"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                />
              </svg>
              <span class="font-medium">Add to Home Screen</span>
            </div>
          </div>
        </div>
      </.surface_panel>

      <.surface_panel>
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            3
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap "Add"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              The app will be added to your home screen.
            </p>
            <div class="p-3 flex items-center justify-start bg-base-300/70 dark:bg-white/5 rounded-lg">
              <svg class="h-7" viewBox="0 0 52 28" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect
                  x="1"
                  y="1"
                  width="50"
                  height="26"
                  rx="13"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  opacity="0.3"
                />
                <text
                  x="26"
                  y="18.5"
                  font-family="system-ui, -apple-system, sans-serif"
                  font-size="13"
                  font-weight="600"
                  fill="currentColor"
                  text-anchor="middle"
                >
                  Add
                </text>
              </svg>
            </div>
          </div>
        </div>
      </.surface_panel>

      <.surface_panel>
        <div class="flex gap-4">
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">That's it.</h3>
            <p class="text-sm text-base-content/70 mb-3">
              Find the new app icon on your home screen. Tap to launch!
            </p>
            <div class="p-3 flex items-center gap-3 bg-base-300/70 dark:bg-white/5 rounded-lg">
              <img src="/images/qadabra_logo_squares_color.svg" class="w-12 h-12 rounded-xl" />
              <div>
                <p class="font-bold">Qadabra</p>
                <p class="text-xs text-base-content/60">Tap to launch</p>
              </div>
            </div>
          </div>
        </div>
      </.surface_panel>
    </div>
    """
  end

  defp android_install_guide(assigns) do
    ~H"""
    <.install_guide_header />

    <div class="space-y-6">
      <.surface_panel>
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
      </.surface_panel>

      <.surface_panel>
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
            <div class="p-3 flex items-center gap-2 bg-base-300/70 dark:bg-white/5 rounded-lg">
              <.icon name="hero-arrow-down-tray" class="w-6 h-6 text-base-content" />
              <span class="font-medium">Install app</span>
            </div>
          </div>
        </div>
      </.surface_panel>

      <.surface_panel>
        <div class="flex gap-4">
          <div class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
            3
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-lg mb-2">Tap "Install"</h3>
            <p class="text-sm text-base-content/70 mb-3">
              The app will be added to your home screen. Tap the icon to launch!
            </p>
            <div class="p-3 flex items-center gap-3 bg-base-300/70 dark:bg-white/5 rounded-lg">
              <img src="/images/qadabra_logo_squares_color.svg" class="w-12 h-12 rounded-xl" />
              <div>
                <p class="font-bold">Qadabra</p>
                <p class="text-xs text-base-content/60">Tap to launch</p>
              </div>
            </div>
          </div>
        </div>
      </.surface_panel>
    </div>
    """
  end

  defp carousel(assigns) do
    ~H"""
    <div class="carousel carousel-center w-full max-w-7xl space-x-4 px-4">
      <div id="card1" class="carousel-item w-[85%] md:w-[300px]">
        <.surface_panel padding={false} class="w-full">
          <figure class="h-48 sm:h-56 md:h-64 bg-gradient-to-br from-green-400 to-emerald-600 relative overflow-hidden">
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
          <div class="p-6">
            <h2 class="text-3xl font-bold mb-3">Sell your attention.</h2>
            <p class="text-base-content/70 text-lg">
              Let advertisers buy attention directly from the source -
              <span class="font-extrabold">you.</span>
            </p>
            <div class="flex justify-center mt-4">
              <img src="/images/Sponster_logo_color_horiz.svg" alt="Sponster" class="h-8 w-auto" />
            </div>
          </div>
        </.surface_panel>
      </div>

      <div id="card2" class="carousel-item w-[85%] md:w-[300px]">
        <.surface_panel padding={false} class="w-full">
          <figure class="h-48 sm:h-56 md:h-64 bg-gradient-to-br from-cyan-400 to-blue-600 relative overflow-hidden">
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
          <div class="p-6">
            <h2 class="text-3xl font-bold mb-3">Fuel your wallet.</h2>
            <p class="text-base-content/70 text-lg">
              Collect ad revenues into your Qadabra wallet.
            </p>
            <div class="flex justify-center mt-4">
              <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="h-8 w-auto" />
            </div>
          </div>
        </.surface_panel>
      </div>

      <div id="card3" class="carousel-item w-[85%] md:w-[300px]">
        <.surface_panel padding={false} class="w-full">
          <figure class="h-48 sm:h-56 md:h-64 bg-gradient-to-br from-orange-400 to-red-600 relative overflow-hidden">
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
          <div class="p-6">
            <h2 class="text-3xl font-bold mb-3">Buy your media.</h2>
            <p class="text-base-content/70 text-lg">
              Use funds to buy access to your favorite media.
            </p>
            <div class="flex justify-center mt-4">
              <img src="/images/Tiqit_logo_color_horiz.svg" alt="Tiqit" class="h-8 w-auto" />
            </div>
          </div>
        </.surface_panel>
      </div>

      <div id="card4" class="carousel-item w-[85%] md:w-[300px]">
        <.surface_panel padding={false} class="w-full">
          <figure class="h-48 sm:h-56 md:h-64 bg-gradient-to-br from-purple-400 to-indigo-600 relative overflow-hidden">
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
          <div class="p-6">
            <h2 class="text-3xl font-bold mb-3">Own your data.</h2>
            <p class="text-base-content/70 text-lg">
              Absolute privacy and ownership of your data.
            </p>
            <div class="flex justify-center mt-4">
              <img src="/images/YouData_logo_color_horiz.svg" alt="YouData" class="h-8 w-auto" />
            </div>
          </div>
        </.surface_panel>
      </div>
    </div>

    <div class="flex justify-center gap-2 py-4">
      <a
        href="#card1"
        data-indicator="1"
        class="carousel-indicator h-3 w-6 rounded-full bg-primary hover:bg-primary/90 transition-all duration-300"
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
