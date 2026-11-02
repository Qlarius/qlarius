defmodule QlariusWeb.PlaybackPositionHook do
  @moduledoc """
  Saves audio playback positions pushed by the `PlaybackResume` hook.
  """

  import Phoenix.LiveView

  alias Qlarius.Tiqit.PlaybackPositions

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :save_playback_position, :handle_event, &handle_event/3)}
  end

  defp handle_event("save_playback_position", params, socket) do
    case socket.assigns[:current_scope] do
      %{user: %{me_file: %{id: me_file_id}}} when is_integer(me_file_id) ->
        PlaybackPositions.save(me_file_id, params)

      _ ->
        :ok
    end

    {:halt, socket}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
