defmodule QlariusWeb.UserSettingsLive do
  use QlariusWeb, :live_view

  import QlariusWeb.PWAHelpers

  def render(assigns) do
    ~H"""
    <div id="settings-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns}>
        <div class="mx-auto max-w-sm">
        <.header class="text-center">
          Account Settings
          <:subtitle>Manage your account settings</:subtitle>
        </.header>

        <div class="space-y-12 divide-y">
          <div class="pt-6">
            <.button navigate={~p"/proxy_users"}>
              Manage Proxy Users →
            </.button>
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
     |> assign(:title, "Settings")
     |> assign(:is_pwa, false)
     |> assign(:device_type, :desktop)}
  end

  def handle_event("pwa_detected", params, socket) do
    handle_pwa_detection(socket, params)
  end
end
