defmodule QlariusWeb.PWAHelpers do
  @moduledoc false

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Initialize PWA-related assigns.
  Reads is_pwa from session (set by StorePWASession plug from cookie).
  Falls back to false if not found - JS will detect and update if needed.
  """
  def init_pwa_assigns(socket, session \\ %{}) do
    is_mobile = socket.assigns[:is_mobile] || false

    # Read from session (which was set from cookie by StorePWASession plug)
    # This ensures the initial render has the correct PWA status
    is_pwa = session["is_pwa"] || false

    # Debug logging
    IO.puts("🔍 [PWA Helpers] is_mobile=#{inspect(is_mobile)} is_pwa from session=#{inspect(is_pwa)}")

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
