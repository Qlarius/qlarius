defmodule QlariusWeb.PWAInstallHooks do
  @moduledoc """
  LiveView hooks for PWA install tracking and mobile-browser redirects.

  Authenticated users on mobile Safari/Chrome are sent to `/hi` for install
  instructions so iOS saves the correct home-screen URL.
  """

  import Phoenix.Component, only: [assign: 3, assign_new: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3, push_navigate: 2]

  use Phoenix.VerifiedRoutes,
    endpoint: QlariusWeb.Endpoint,
    router: QlariusWeb.Router,
    statics: QlariusWeb.static_paths()

  def on_mount(:require_pwa_on_mobile, _params, session, socket) do
    is_mobile = session["is_mobile"] || false
    is_pwa = session["is_pwa"] || false

    if is_mobile && !is_pwa do
      {:halt, push_navigate(socket, to: ~p"/hi")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:default, _params, session, socket) do
    {:cont,
     socket
     |> assign_new(:is_pwa, fn -> session["is_pwa"] || false end)
     |> attach_hook(:pwa_install_events, :handle_event, &handle_pwa_events/3)}
  end

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

    if redirect_to_hi?(socket, is_ios, is_android, is_pwa) do
      {:halt, push_navigate(socket, to: ~p"/hi")}
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

    {:halt, socket}
  end

  defp handle_pwa_events(_event, _params, socket) do
    {:cont, socket}
  end

  defp redirect_to_hi?(socket, is_ios, is_android, is_pwa) do
    is_mobile = is_ios || is_android
    is_mobile && !is_pwa && !!socket.assigns[:current_scope]
  end

  defp get_user_id(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{id: id}}} -> id
      _ -> nil
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
