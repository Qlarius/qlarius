defmodule QlariusWeb.Components.PWAInstallPrompt do
  use Phoenix.Component
  import QlariusWeb.CoreComponents
  alias Phoenix.LiveView.JS

  attr :show_banner, :boolean, default: false
  attr :is_ios, :boolean, default: false
  attr :is_android, :boolean, default: false

  def install_banner(assigns) do
    ~H"""
    <%= if @show_banner do %>
      <div
        id="pwa-install-banner"
        class="fixed bottom-20 max-w-md mx-auto left-4 right-4 z-45 transform translate-y-full opacity-0"
        phx-mounted={
          JS.transition(
            {"ease-out duration-500", "translate-y-full opacity-0", "translate-y-0 opacity-100"},
            time: 300
          )
        }
      >
        <div class="shadow-xl bg-base-100 dark:bg-base-200 !border-2 !border-primary rounded-xl overflow-hidden">
          <%!-- Header banner with logo and close button --%>
          <div class="bg-base-200 dark:bg-base-300 px-4 py-3 flex items-center justify-center relative">
            <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="h-8 w-auto" />
            <button
              phx-click="dismiss_install_banner"
              class="absolute right-4 btn btn-default btn-xs btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content" />
            </button>
          </div>

          <%!-- Content area --%>
          <div class="p-6">
            <p class="text-lg leading-relaxed text-base-content dark:text-base-content/90">
              <span class="block font-bold text-xl mb-2">Get the Full Experience</span>
              <span class="block mt-2">
                Install Qadabra for instant access, full-screen mode, and push notifications.
              </span>
            </p>

            <div class="flex flex-col gap-2 mt-4">
              <%= if @is_ios do %>
                <button
                  phx-click="show_ios_guide"
                  class="btn btn-primary rounded-full btn-block font-semibold cursor-pointer"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Install App
                </button>
              <% end %>

              <%= if @is_android do %>
                <button
                  id="android-install-button"
                  phx-click="show_android_guide"
                  class="btn btn-primary btn-block font-semibold"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Install App
                </button>
              <% end %>

              <button
                phx-click="dismiss_install_banner"
                class="btn btn-ghost btn-block"
              >
                Maybe Later
              </button>
            </div>
          </div>
          <%!-- End content area --%>
        </div>
      </div>
    <% end %>
    """
  end

  attr :show, :boolean, required: true

  def ios_install_guide(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="modal modal-open" phx-click="hide_ios_guide">
        <div
          class="shadow-xl bg-base-100 dark:bg-base-200 !border-2 !border-primary rounded-xl overflow-hidden max-w-lg mx-4"
          phx-click="stop_propagation"
        >
          <%!-- Header banner with logo and close button --%>
          <div class="bg-base-200 dark:bg-base-300 px-4 py-3 flex items-center justify-center relative">
            <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="h-8 w-auto" />
            <button
              phx-click="hide_ios_guide"
              class="absolute right-4 btn btn-default btn-xs btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content" />
            </button>
          </div>

          <%!-- Content area --%>
          <div class="p-4 space-y-4">
            <p class="text-base leading-snug text-base-content dark:text-base-content/90">
              <span class="block font-bold text-lg mb-2">Install Qadabra</span>
              <span class="block text-sm">
                Get the best mobile experience with easy home screen access, full-screen mobile experience, and importantnotifications.
              </span>
            </p>

            <ol class="space-y-3">
              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  1
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">Tap the Share button</p>
                  <p class="text-xs text-base-content/70 mb-1.5">
                    Look for it at the bottom center of Safari
                  </p>
                  <div class="bg-base-200 rounded-lg p-2">
                    <div class="flex items-center gap-1 text-xs">
                      <.icon name="hero-arrow-up-on-square" class="w-4 h-4 text-base-content" />
                      <span class="font-medium">Share</span>
                      <span class="font-medium">(might need to click ... first))</span>
                    </div>
                  </div>
                </div>
              </li>

              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  2
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">Select "Add to Home Screen"</p>
                  <p class="text-xs text-base-content/70 mb-1.5">
                    Scroll down in the menu if you don't see it immediately
                  </p>
                  <div class="bg-base-200 rounded-lg p-2">
                    <div class="flex items-center gap-1 text-xs">
                      <.icon name="hero-plus-circle" class="w-4 h-4 text-base-content" />
                      <span class="font-medium">Add to Home Screen</span>
                    </div>
                  </div>
                </div>
              </li>

              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  3
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">Tap "Add"</p>
                  <p class="text-xs text-base-content/70 mb-1.5">
                    Qadabra will appear on your home screen with a custom icon
                  </p>
                  <div class="bg-base-200 rounded-lg p-2 flex items-center gap-2">
                    <img src="/images/qadabra_logo_squares_color.svg" class="w-10 h-10 rounded-xl" />
                    <div>
                      <p class="font-medium text-sm">Qadabra</p>
                      <p class="text-xs text-base-content/60">Tap to launch</p>
                    </div>
                  </div>
                </div>
              </li>
            </ol>

            <button
              phx-click="hide_ios_guide"
              class="btn btn-primary rounded-full btn-block mt-4 cursor-pointer"
            >
              Got It! Let's Install
            </button>
          </div>
          <%!-- End content area --%>
        </div>
      </div>
    <% end %>
    """
  end

  attr :show, :boolean, required: true

  def android_install_guide(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="modal modal-open" phx-click="hide_android_guide">
        <div
          class="shadow-xl bg-base-100 dark:bg-base-200 !border-2 !border-primary rounded-xl overflow-hidden max-w-lg mx-4"
          phx-click="stop_propagation"
        >
          <%!-- Header banner with logo and close button --%>
          <div class="bg-base-200 dark:bg-base-300 px-4 py-3 flex items-center justify-center relative">
            <img src="/images/qadabra_logo_squares_color.svg" alt="Qadabra" class="h-8 w-auto" />
            <button
              phx-click="hide_android_guide"
              class="absolute right-4 btn btn-default btn-xs btn-circle"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5 text-base-content" />
            </button>
          </div>

          <%!-- Content area --%>
          <div class="p-4 space-y-4">
            <p class="text-base leading-snug text-base-content dark:text-base-content/90">
              <span class="block font-bold text-lg mb-2">Install Qadabra</span>
              <span class="block text-sm">
                Transform your browser experience into a fast, native-feeling app.
              </span>
            </p>

            <div class="bg-base-200 dark:bg-base-300 rounded-lg p-3">
              <p class="font-semibold mb-1 text-sm text-base-content">Why install?</p>
              <ul class="space-y-0.5 text-xs text-base-content/80">
                <li>• Launch directly from your home screen</li>
                <li>• Immersive full-screen experience</li>
                <li>• Instant notifications for new offers</li>
                <li>• Faster performance, smaller storage</li>
              </ul>
            </div>

            <div class="bg-gradient-to-br from-primary/10 to-secondary/10 rounded-xl p-3 text-center">
              <.icon name="hero-cursor-arrow-ripple" class="w-10 h-10 text-primary mx-auto mb-2" />
              <p class="font-semibold text-base mb-1">Ready to install?</p>
              <p class="text-xs text-base-content/70 mb-3">
                Your browser will show an install prompt. Just tap "Install" or "Add" when it appears.
              </p>
              <button id="trigger-android-install" class="btn btn-primary">
                <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Install Now
              </button>
            </div>

            <div class="divider text-xs text-base-content/60 my-3">OR INSTALL MANUALLY</div>

            <ol class="space-y-3">
              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  1
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">Tap the menu (⋮)</p>
                  <p class="text-xs text-base-content/70">
                    Usually in the top-right corner of Chrome or your browser
                  </p>
                </div>
              </li>

              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  2
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">
                    Select "Install app" or "Add to Home screen"
                  </p>
                  <p class="text-xs text-base-content/70">
                    The wording may vary by browser
                  </p>
                </div>
              </li>

              <li class="flex gap-3">
                <span class="flex-shrink-0 w-8 h-8 bg-primary text-white rounded-full flex items-center justify-center font-bold text-base">
                  3
                </span>
                <div class="flex-1">
                  <p class="font-semibold text-base mb-0.5">Confirm installation</p>
                  <p class="text-xs text-base-content/70">
                    Qadabra will be added to your home screen and app drawer
                  </p>
                </div>
              </li>
            </ol>

            <button phx-click="hide_android_guide" class="btn btn-ghost btn-block mt-4">
              Maybe Later
            </button>
          </div>
          <%!-- End content area --%>
        </div>
      </div>
    <% end %>
    """
  end
end
