defmodule QlariusWeb.PWAInstallHooks do
  @moduledoc """
  LiveView hooks for handling PWA installation prompts and tracking.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:show_install_banner, false)
     |> assign(:show_ios_guide, false)
     |> assign(:show_android_guide, false)
     |> assign(:is_ios, false)
     |> assign(:is_android, false)
     |> assign(:is_pwa, false)
     |> attach_hook(:pwa_install_events, :handle_event, &handle_pwa_events/3)}
  end

  defp handle_pwa_events(
         "check_pwa_state",
         %{"is_ios" => is_ios, "is_android" => is_android, "is_pwa" => is_pwa},
         socket
       ) do
    user_id = get_user_id(socket)
    should_show = should_show_install_banner?(user_id, is_ios, is_android, is_pwa)

    {:halt,
     socket
     |> assign(:is_ios, is_ios)
     |> assign(:is_android, is_android)
     |> assign(:is_pwa, is_pwa)
     |> assign(:show_install_banner, should_show)}
  end

  defp handle_pwa_events("show_ios_guide", _params, socket) do
    {:halt, assign(socket, :show_ios_guide, true)}
  end

  defp handle_pwa_events("hide_ios_guide", _params, socket) do
    {:halt, assign(socket, :show_ios_guide, false)}
  end

  defp handle_pwa_events("show_android_guide", _params, socket) do
    {:halt, assign(socket, :show_android_guide, true)}
  end

  defp handle_pwa_events("hide_android_guide", _params, socket) do
    {:halt, assign(socket, :show_android_guide, false)}
  end

  defp handle_pwa_events("dismiss_install_banner", _params, socket) do
    user_id = get_user_id(socket)

    if user_id do
      store_dismissal(user_id)
    end

    {:halt,
     socket
     |> assign(:show_install_banner, false)}
  end

  defp handle_pwa_events("pwa_installed", _params, socket) do
    user_id = get_user_id(socket)

    socket =
      if user_id do
        case mark_pwa_installed(user_id) do
          {:ok, :newly_installed} ->
            socket
            |> assign(:show_install_banner, false)
            |> assign(:is_pwa, true)
            |> put_flash(:info, "🎉 Welcome to the Qlarius app!")

          {:ok, :already_installed} ->
            socket
            |> assign(:show_install_banner, false)
            |> assign(:is_pwa, true)
        end
      else
        socket
        |> assign(:show_install_banner, false)
        |> assign(:is_pwa, true)
      end

    {:halt, socket}
  end

  defp handle_pwa_events(_event, _params, socket) do
    {:cont, socket}
  end

  defp get_user_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: id}}} -> id
      _ -> nil
    end
  end

  defp should_show_install_banner?(user_id, is_ios, is_android, is_pwa) do
    cond do
      is_pwa -> false
      !is_ios && !is_android -> false
      recently_dismissed?(user_id) -> false
      true -> true
    end
  end

  defp recently_dismissed?(nil), do: false

  defp recently_dismissed?(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      nil ->
        false

      user ->
        case user.pwa_install_dismissed_at do
          nil ->
            false

          dismissed_at ->
            days_ago = DateTime.diff(DateTime.utc_now(), dismissed_at, :day)
            days_ago < 7
        end
    end
  end

  defp store_dismissal(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      nil ->
        :ok

      user ->
        user
        |> Ecto.Changeset.change(%{pwa_install_dismissed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
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
