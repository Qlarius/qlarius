defmodule QlariusWeb.Components.PWAInstallPrompt do
  use Phoenix.Component
  import QlariusWeb.CoreComponents

  attr :show_banner, :boolean, default: false
  attr :is_ios, :boolean, default: false
  attr :is_android, :boolean, default: false

  def install_banner(assigns) do
    ~H"""
    <div
      :if={@show_banner}
      id="pwa-install-banner"
      class="fixed bottom-20 left-0 right-0 bg-gradient-to-r from-primary to-secondary text-white p-4 shadow-2xl z-40 safe-area-inset-bottom animate-slide-up"
    >
      <div class="max-w-2xl mx-auto">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-start gap-3 flex-1">
            <img src="/images/qadabra_icon.png" class="w-12 h-12 rounded-xl shadow-lg flex-shrink-0" />
            <div class="flex-1 min-w-0">
              <p class="font-bold text-lg mb-1">Get the Full Experience</p>
              <p class="text-sm opacity-95 leading-snug">
                Install Qlarius for instant access, full-screen mode, and push notifications
              </p>
            </div>
          </div>
          <button
            phx-click="dismiss_install_banner"
            class="text-white/80 hover:text-white flex-shrink-0 p-1"
            aria-label="Dismiss"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>
        </div>

        <div class="flex gap-2 mt-4">
          <%= if @is_ios do %>
            <button
              phx-click="show_ios_guide"
              class="btn btn-sm bg-white text-primary hover:bg-white/90 flex-1 font-semibold"
            >
              <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
              Install App
            </button>
          <% end %>

          <%= if @is_android do %>
            <button
              id="android-install-button"
              phx-click="show_android_guide"
              class="btn btn-sm bg-white text-primary hover:bg-white/90 flex-1 font-semibold"
            >
              <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
              Install App
            </button>
          <% end %>

          <button
            phx-click="dismiss_install_banner"
            class="btn btn-sm btn-ghost text-white hover:bg-white/20"
          >
            Maybe Later
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :show, :boolean, required: true

  def ios_install_guide(assigns) do
    ~H"""
    <div
      :if={@show}
      class="modal modal-open"
      phx-click="hide_ios_guide"
    >
      <div class="modal-box max-w-lg" phx-click="stop_propagation">
        <div class="text-center mb-6">
          <div class="inline-flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full mb-4">
            <.icon name="hero-device-phone-mobile" class="w-8 h-8 text-primary" />
          </div>
          <h2 class="text-2xl font-bold mb-2">Install Qlarius</h2>
          <p class="text-base-content/70">
            Get the best mobile experience with quick access, full-screen mode, and notifications
          </p>
        </div>

        <div class="space-y-6 mb-6">
          <div class="alert alert-info">
            <.icon name="hero-information-circle" class="w-5 h-5" />
            <div class="text-sm">
              <p class="font-semibold">Benefits of installing:</p>
              <ul class="mt-1 space-y-1">
                <li>• Launch instantly from your home screen</li>
                <li>• Full-screen experience like a native app</li>
                <li>• Receive push notifications for new ads</li>
                <li>• Works offline for viewing your data</li>
              </ul>
            </div>
          </div>

          <ol class="space-y-4">
            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                1
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Tap the Share button</p>
                <p class="text-sm text-base-content/70 mb-2">
                  Look for <.icon name="hero-share" class="inline w-4 h-4" /> at the bottom center of Safari
                </p>
                <div class="bg-base-200 rounded-lg p-3 flex items-center justify-center">
                  <div class="text-center">
                    <.icon name="hero-share" class="w-8 h-8 text-primary mx-auto mb-1" />
                    <p class="text-xs text-base-content/60">Share Button</p>
                  </div>
                </div>
              </div>
            </li>

            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                2
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Select "Add to Home Screen"</p>
                <p class="text-sm text-base-content/70 mb-2">
                  Scroll down in the menu if you don't see it immediately
                </p>
                <div class="bg-base-200 rounded-lg p-3">
                  <div class="flex items-center gap-2 text-sm">
                    <.icon name="hero-plus-circle" class="w-5 h-5 text-primary" />
                    <span class="font-medium">Add to Home Screen</span>
                  </div>
                </div>
              </div>
            </li>

            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                3
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Tap "Add"</p>
                <p class="text-sm text-base-content/70 mb-2">
                  Qlarius will appear on your home screen with a custom icon
                </p>
                <div class="bg-base-200 rounded-lg p-3 flex items-center gap-3">
                  <img src="/images/qadabra_icon.png" class="w-12 h-12 rounded-xl" />
                  <div>
                    <p class="font-medium">Qlarius</p>
                    <p class="text-xs text-base-content/60">Tap to launch</p>
                  </div>
                </div>
              </div>
            </li>
          </ol>
        </div>

        <div class="modal-action">
          <button
            phx-click="hide_ios_guide"
            class="btn btn-primary btn-block btn-lg"
          >
            Got It! Let's Install
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :show, :boolean, required: true

  def android_install_guide(assigns) do
    ~H"""
    <div
      :if={@show}
      class="modal modal-open"
      phx-click="hide_android_guide"
    >
      <div class="modal-box max-w-lg" phx-click="stop_propagation">
        <div class="text-center mb-6">
          <div class="inline-flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full mb-4">
            <.icon name="hero-device-phone-mobile" class="w-8 h-8 text-primary" />
          </div>
          <h2 class="text-2xl font-bold mb-2">Install Qlarius</h2>
          <p class="text-base-content/70">
            Transform your browser experience into a fast, native-feeling app
          </p>
        </div>

        <div class="space-y-6 mb-6">
          <div class="alert alert-info">
            <.icon name="hero-information-circle" class="w-5 h-5" />
            <div class="text-sm">
              <p class="font-semibold">Why install?</p>
              <ul class="mt-1 space-y-1">
                <li>• Launch directly from your home screen</li>
                <li>• Immersive full-screen experience</li>
                <li>• Instant notifications for new offers</li>
                <li>• Faster performance, smaller storage</li>
                <li>• Works offline when you need it</li>
              </ul>
            </div>
          </div>

          <div class="bg-gradient-to-br from-primary/10 to-secondary/10 rounded-xl p-6 text-center">
            <.icon name="hero-cursor-arrow-ripple" class="w-12 h-12 text-primary mx-auto mb-3" />
            <p class="font-semibold text-lg mb-2">Ready to install?</p>
            <p class="text-sm text-base-content/70 mb-4">
              Your browser will show an install prompt. Just tap "Install" or "Add" when it appears.
            </p>
            <button
              id="trigger-android-install"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
              Install Now
            </button>
          </div>

          <div class="divider text-xs text-base-content/60">OR INSTALL MANUALLY</div>

          <ol class="space-y-4">
            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                1
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Tap the menu (⋮)</p>
                <p class="text-sm text-base-content/70">
                  Usually in the top-right corner of Chrome or your browser
                </p>
              </div>
            </li>

            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                2
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Select "Install app" or "Add to Home screen"</p>
                <p class="text-sm text-base-content/70">
                  The wording may vary by browser
                </p>
              </div>
            </li>

            <li class="flex gap-4">
              <span class="flex-shrink-0 w-10 h-10 bg-primary text-white rounded-full flex items-center justify-center font-bold text-lg">
                3
              </span>
              <div class="flex-1 pt-1">
                <p class="font-semibold text-lg mb-1">Confirm installation</p>
                <p class="text-sm text-base-content/70">
                  Qlarius will be added to your home screen and app drawer
                </p>
              </div>
            </li>
          </ol>
        </div>

        <div class="modal-action">
          <button
            phx-click="hide_android_guide"
            class="btn btn-ghost"
          >
            Maybe Later
          </button>
        </div>
      </div>
    </div>
    """
  end
end
