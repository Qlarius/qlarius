defmodule QlariusWeb.PWAHelpers do
  @moduledoc false

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_navigate: 2]

  @doc """
  Initialize PWA-related assigns with smart defaults to prevent layout flash.
  Assumes mobile devices are PWAs (corrected by JS if wrong).
  """
  def init_pwa_assigns(socket) do
    is_mobile = socket.assigns[:is_mobile] || false

    socket
    |> assign(:is_pwa, is_mobile)
    |> assign(:device_type, if(is_mobile, do: :mobile_phone, else: :desktop))
  end

  def handle_pwa_detection(socket, %{"is_pwa" => is_pwa, "device_type" => device_type}) do
    device_type_atom =
      case device_type do
        "ios_phone" -> :ios_phone
        "android_phone" -> :android_phone
        "desktop" -> :desktop
        _ -> :mobile_phone
      end

    socket =
      socket
      |> assign(:is_pwa, is_pwa)
      |> assign(:device_type, device_type_atom)

    {:noreply, socket}
  end
end
