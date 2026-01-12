defmodule QlariusWeb.LogoutModalHooks do
  @moduledoc """
  LiveView hooks for handling logout confirmation modal.
  Provides default handlers for logout modal that work across all LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:show_logout_modal, false)
     |> attach_hook(:logout_modal_events, :handle_event, &handle_logout_events/3)}
  end

  defp handle_logout_events("show_logout_modal", _params, socket) do
    {:halt, assign(socket, :show_logout_modal, true)}
  end

  defp handle_logout_events("cancel_logout", _params, socket) do
    {:halt, assign(socket, :show_logout_modal, false)}
  end

  defp handle_logout_events(_event, _params, socket) do
    {:cont, socket}
  end
end
