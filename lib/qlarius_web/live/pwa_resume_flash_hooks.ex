defmodule QlariusWeb.PWAResumeFlashHooks do
  @moduledoc """
  Shows a notice when an iOS PWA reloaded after the user switched back to it.

  The client sends `pwa_bg_pending` only when this same visit was backgrounded
  and the document then reloaded. A fresh launch from the home screen does not
  send it: that flag used to live only in localStorage, so it survived quitting
  and the next open looked like a return.
  """

  import Phoenix.LiveView

  @clear_event "pwa_clear_bg_pending"

  def on_mount(:default, _params, _session, socket) do
    socket =
      if connected?(socket) do
        connect_params = get_connect_params(socket) || %{}

        pending =
          case connect_params do
            %{"pwa_bg_pending" => "1"} -> true
            %{pwa_bg_pending: "1"} -> true
            _ -> false
          end

        if pending do
          socket
          |> put_flash(:info, "The app refreshed while you were away.")
          |> push_event(@clear_event, %{})
        else
          socket
        end
      else
        socket
      end

    {:cont, socket}
  end
end

