defmodule QlariusWeb.Settings.NotificationsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.PWAHelpers

  def render(assigns) do
    ~H"""
    <div id="notifications-settings-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="mx-auto max-w-2xl">
          <button phx-click="navigate_to_settings" class="btn btn-outline rounded-full text-lg mb-4 !border-base-content/30 !px-3 !py-1">
            <.icon name="hero-chevron-left" class="w-5 h-5" /> Back
          </button>

          <div class="mb-6">
            <h1 class="text-2xl font-bold text-base-content mb-2">Notifications</h1>
            <p class="text-base-content/60">Manage your notification preferences</p>
          </div>

          <div class="flex items-center justify-center min-h-[50vh]">
            <div class="text-center">
              <p class="text-xl text-base-content/70 mb-2">Coming soon</p>
              <p class="text-base-content/50">Notification settings will be available here.</p>
            </div>
          </div>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Notifications")
     |> assign(:current_path, "/settings/notifications")
     |> assign(:is_pwa, false)
     |> assign(:device_type, :desktop)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end

  def handle_event("navigate_to_settings", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/settings")}
  end
end
