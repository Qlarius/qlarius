defmodule QlariusWeb.TimezoneHooks do
  @moduledoc """
  LiveView hooks for assigning user timezone to socket.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:assign_timezone, _params, _session, socket) do
    timezone =
      case socket.assigns do
        %{current_scope: %{user: %{timezone: tz}}} when is_binary(tz) -> tz
        _ -> Qlarius.Timezones.default()
      end

    {:cont, assign(socket, :timezone, timezone)}
  end
end
