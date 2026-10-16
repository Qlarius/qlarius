defmodule QlariusWeb.PWAInstallHooks do
  @moduledoc """
  LiveView hooks for PWA install tracking and mobile-browser redirects.

  Authenticated users on mobile Safari/Chrome are sent to `/hi` for install
  instructions so iOS saves the correct home-screen URL.

  The exception is a new user arriving from a gift claim (`welcome=gift`): they
  stay on the page with their tiqit and get a dismissible install banner instead.
  """

  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView,
    only: [attach_hook: 4, detach_hook: 3, put_flash: 3, push_navigate: 2]

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  @dismissal_days 7

  def on_mount(:require_pwa_on_mobile, params, session, socket) do
    is_mobile = session["is_mobile"] || false
    is_pwa = session["is_pwa"] || false
    mobile_browser_ok = session["mobile_browser_ok"] || false

    cond do
      soft_install_params?(params) ->
        {:cont, assign(socket, :soft_install?, true)}

      is_mobile && !is_pwa && !mobile_browser_ok ->
        {:halt, push_navigate(socket, to: ~p"/hi")}

      true ->
        {:cont, assign(socket, :soft_install?, false)}
    end
  end

  def on_mount(:default, _params, session, socket) do
    {:cont,
     socket
     |> assign(:is_pwa, session["is_pwa"] || false)
     |> assign(:mobile_browser_ok, session["mobile_browser_ok"] || false)
     |> assign(:soft_install?, socket.assigns[:soft_install?] == true)
     |> assign(:show_install_banner, false)
     |> assign(:show_ios_guide, false)
     |> assign(:show_android_guide, false)
     |> detach_hook(:pwa_install_events, :handle_event)
     |> attach_hook(:pwa_install_events, :handle_event, &handle_pwa_events/3)}
  end

  defp soft_install_params?(%{"welcome" => "gift"}), do: true
  defp soft_install_params?(_params), do: false

  defp handle_pwa_events(
         "check_pwa_state",
         %{"is_ios" => is_ios, "is_android" => is_android, "is_pwa" => is_pwa},
         socket
       ) do
    socket =
      socket
      |> assign(:is_ios, is_ios)
      |> assign(:is_android, is_android)
      |> assign(:is_pwa, is_pwa)

    cond do
      socket.assigns[:soft_install?] ->
        {:halt, assign(socket, :show_install_banner, show_install_banner?(socket))}

      redirect_to_hi?(socket, is_ios, is_android, is_pwa) ->
        {:halt, push_navigate(socket, to: ~p"/hi")}

      true ->
        {:halt, socket}
    end
  end

  defp handle_pwa_events("pwa_installed", _params, socket) do
    user_id = get_user_id(socket)

    socket =
      if user_id do
        case mark_pwa_installed(user_id) do
          {:ok, :newly_installed} ->
            socket
            |> assign(:is_pwa, true)
            |> put_flash(:info, "🎉 Welcome to the Qadabra app!")

          {:ok, :already_installed} ->
            assign(socket, :is_pwa, true)
        end
      else
        assign(socket, :is_pwa, true)
      end

    {:halt, assign(socket, :show_install_banner, false)}
  end

  defp handle_pwa_events(event, _params, %{assigns: %{soft_install?: true}} = socket)
       when event in ~w(show_ios_guide hide_ios_guide show_android_guide hide_android_guide
                        dismiss_install_banner stop_propagation) do
    {:halt, handle_soft_install_event(event, socket)}
  end

  defp handle_pwa_events(_event, _params, socket) do
    {:cont, socket}
  end

  defp handle_soft_install_event("show_ios_guide", socket),
    do: assign(socket, :show_ios_guide, true)

  defp handle_soft_install_event("hide_ios_guide", socket),
    do: assign(socket, :show_ios_guide, false)

  defp handle_soft_install_event("show_android_guide", socket),
    do: assign(socket, :show_android_guide, true)

  defp handle_soft_install_event("hide_android_guide", socket),
    do: assign(socket, :show_android_guide, false)

  defp handle_soft_install_event("dismiss_install_banner", socket) do
    if user_id = get_user_id(socket), do: store_dismissal(user_id)

    socket
    |> assign(:show_install_banner, false)
    |> put_flash(:info, "You can always install later from your browser menu")
  end

  defp handle_soft_install_event("stop_propagation", socket), do: socket

  defp show_install_banner?(socket) do
    %{is_ios: is_ios, is_android: is_android, is_pwa: is_pwa} = socket.assigns
    (is_ios || is_android) && !is_pwa && !recently_dismissed?(get_user_id(socket))
  end

  defp redirect_to_hi?(socket, is_ios, is_android, is_pwa) do
    is_mobile = is_ios || is_android
    mobile_browser_ok = socket.assigns[:mobile_browser_ok] || false
    is_mobile && !is_pwa && !mobile_browser_ok && !!socket.assigns[:current_scope]
  end

  defp get_user_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: id}}} -> id
      _ -> nil
    end
  end

  defp recently_dismissed?(nil), do: false

  defp recently_dismissed?(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      %{pwa_install_dismissed_at: %DateTime{} = dismissed_at} ->
        DateTime.diff(DateTime.utc_now(), dismissed_at, :day) < @dismissal_days

      _ ->
        false
    end
  end

  defp store_dismissal(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      nil ->
        :ok

      user ->
        user
        |> Ecto.Changeset.change(%{
          pwa_install_dismissed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Qlarius.Repo.update()
    end
  end

  defp mark_pwa_installed(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      nil ->
        {:ok, :already_installed}

      user ->
        if user.pwa_installed do
          {:ok, :already_installed}
        else
          user
          |> Ecto.Changeset.change(%{
            pwa_installed: true,
            pwa_installed_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> Qlarius.Repo.update()
          |> case do
            {:ok, _user} -> {:ok, :newly_installed}
            {:error, _changeset} -> {:ok, :already_installed}
          end
        end
    end
  end
end
