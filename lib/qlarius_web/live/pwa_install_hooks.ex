defmodule QlariusWeb.PWAInstallHooks do
  @moduledoc """
  LiveView hooks for PWA install tracking and the install banner.

  Signed-in app pages (`:install_banner` in the `:current_scope` live session)
  show a dismissible install banner to phone browsers that aren't the installed
  app. Dismissing hides it for 7 days.

  A gift landing (`welcome=gift`) gets no banner, so a recipient reaches the
  tiqit without an install pitch in the way. `/hi` has its own install flow.
  """

  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView, only: [attach_hook: 4, detach_hook: 3, put_flash: 3]

  @dismissal_days 7

  def on_mount(:install_banner, params, _session, socket) do
    {:cont, assign(socket, :soft_install?, !gift_landing?(params))}
  end

  def on_mount(:default, _params, session, socket) do
    {:cont,
     socket
     |> assign(:is_pwa, session["is_pwa"] || false)
     |> assign(:soft_install?, socket.assigns[:soft_install?] == true)
     |> assign(:show_install_banner, false)
     |> assign(:show_ios_guide, false)
     |> assign(:show_android_guide, false)
     |> detach_hook(:pwa_install_events, :handle_event)
     |> attach_hook(:pwa_install_events, :handle_event, &handle_pwa_events/3)}
  end

  defp gift_landing?(%{"welcome" => "gift"}), do: true
  defp gift_landing?(_params), do: false

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

    if socket.assigns[:soft_install?] do
      {:halt, assign(socket, :show_install_banner, show_install_banner?(socket))}
    else
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
