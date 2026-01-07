defmodule QlariusWeb.PWAInstallLive do
  @moduledoc """
  Handles PWA installation prompts and guides for mobile users.
  Provides platform-specific instructions and tracks install state.
  """

  use QlariusWeb, :live_view

  def mount(_params, _session, socket) do
    user_id = socket.assigns[:current_scope][:user][:id]

    {:ok,
     socket
     |> assign(:show_install_banner, false)
     |> assign(:show_ios_guide, false)
     |> assign(:show_android_guide, false)
     |> assign(:is_ios, false)
     |> assign(:is_android, false)
     |> assign(:is_pwa, false)
     |> assign(:user_id, user_id)}
  end

  def handle_event(
        "check_pwa_state",
        %{"is_ios" => is_ios, "is_android" => is_android, "is_pwa" => is_pwa},
        socket
      ) do
    should_show = should_show_install_banner?(socket.assigns.user_id, is_ios, is_android, is_pwa)

    {:noreply,
     socket
     |> assign(:is_ios, is_ios)
     |> assign(:is_android, is_android)
     |> assign(:is_pwa, is_pwa)
     |> assign(:show_install_banner, should_show)}
  end

  def handle_event("show_ios_guide", _params, socket) do
    {:noreply, assign(socket, :show_ios_guide, true)}
  end

  def handle_event("show_android_guide", _params, socket) do
    {:noreply, assign(socket, :show_android_guide, true)}
  end

  def handle_event("dismiss_install_banner", _params, socket) do
    if socket.assigns.user_id do
      store_dismissal(socket.assigns.user_id)
    end

    {:noreply,
     socket
     |> assign(:show_install_banner, false)
     |> put_flash(:info, "You can always install later from your browser menu")}
  end

  def handle_event("pwa_installed", _params, socket) do
    if socket.assigns.user_id do
      mark_pwa_installed(socket.assigns.user_id)
    end

    {:noreply,
     socket
     |> assign(:show_install_banner, false)
     |> assign(:is_pwa, true)
     |> put_flash(:info, "🎉 Welcome to the Qlarius app!")}
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
        |> Ecto.Changeset.change(%{pwa_install_dismissed_at: DateTime.utc_now()})
        |> Qlarius.Repo.update()
    end
  end

  defp mark_pwa_installed(user_id) do
    case Qlarius.Repo.get(Qlarius.Accounts.User, user_id) do
      nil ->
        :ok

      user ->
        user
        |> Ecto.Changeset.change(%{
          pwa_installed: true,
          pwa_installed_at: DateTime.utc_now()
        })
        |> Qlarius.Repo.update()
    end
  end
end
