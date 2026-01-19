defmodule QlariusWeb.PWAHelpers do
  @moduledoc false

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Initialize PWA-related assigns.
  On first mount (no existing is_pwa assign), assume mobile = PWA.
  JS will detect actual PWA status and update assigns once.
  """
  def init_pwa_assigns(socket, _session \\ %{}) do
    is_mobile = socket.assigns[:is_mobile] || false

    # Default: assume mobile devices are PWAs
    # JS detection will correct this once on connected mount
    is_pwa = is_mobile

    # Debug logging
    IO.puts("🔍 [PWA Helpers] is_mobile=#{inspect(is_mobile)} defaulting is_pwa=#{inspect(is_pwa)}")

    socket
    |> assign(:is_pwa, is_pwa)
    |> assign(:device_type, if(is_mobile, do: :mobile_phone, else: :desktop))
  end

  def handle_pwa_detection(socket, %{"is_pwa" => is_pwa, "device_type" => device_type, "is_mobile" => is_mobile}) do
    device_type_atom =
      case device_type do
        "ios_phone" -> :ios_phone
        "android_phone" -> :android_phone
        "desktop" -> :desktop
        _ -> :mobile_phone
      end

    IO.puts("🔄 [PWA Detection Event] is_mobile=#{inspect(is_mobile)} is_pwa=#{inspect(is_pwa)} device_type=#{inspect(device_type)}")
    IO.puts("   Current assigns: is_mobile=#{inspect(socket.assigns[:is_mobile])} is_pwa=#{inspect(socket.assigns[:is_pwa])}")

    # Only update if values actually changed to avoid unnecessary re-render
    socket =
      if socket.assigns[:is_pwa] != is_pwa || socket.assigns[:is_mobile] != is_mobile do
        IO.puts("   ⚠️ Values changed! Updating assigns (this may cause flash)")
        socket
        |> assign(:is_pwa, is_pwa)
        |> assign(:is_mobile, is_mobile)
        |> assign(:device_type, device_type_atom)
      else
        IO.puts("   ✅ Values unchanged, no update needed")
        socket
        |> assign(:device_type, device_type_atom)
      end

    {:noreply, socket}
  end
end
