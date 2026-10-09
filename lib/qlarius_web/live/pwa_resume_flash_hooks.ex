defmodule QlariusWeb.PWAResumeFlashHooks do
  @moduledoc """
  Shows a friendly notice when the app had to reconnect/remount after being backgrounded.

  iOS standalone PWAs may get their WebContent process suspended/evicted. When the app
  returns, LiveView can remount (socket reconnect) or the page can fully reload.
  In either case, we can detect the "coming back from background" signal provided by
  the client via LiveSocket connect params and warn the user that transient UI state
  may have been lost.
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

