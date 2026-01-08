defmodule QlariusWeb.PWAHelpers do
  @moduledoc false

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_navigate: 2]

  def should_redirect_to_pwa_install?(is_pwa, device_type) do
    device_type_atom = if is_binary(device_type), do: String.to_atom(device_type), else: device_type

    !is_pwa && device_type_atom in [:ios_phone, :android_phone]
  end

  def handle_pwa_detection(socket, %{"is_pwa" => is_pwa, "device_type" => device_type}) do
    socket = socket |> assign(:is_pwa, is_pwa) |> assign(:device_type, String.to_atom(device_type))

    if should_redirect_to_pwa_install?(is_pwa, device_type) do
      {:noreply, push_navigate(socket, to: ~p"/hi")}
    else
      {:noreply, socket}
    end
  end
end
