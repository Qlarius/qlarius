defmodule Qlarius.Qai.Anthropic.SSE do
  @moduledoc """
  Incremental server-sent-events parser for the Anthropic Messages stream.

  Network chunks split events arbitrarily, so callers thread a buffer through
  `feed/2`: each call returns the decoded JSON events completed by the new
  chunk plus the leftover bytes to carry into the next call.
  """

  def new, do: ""

  @doc "Returns `{decoded_events, remaining_buffer}`."
  def feed(buffer, chunk) do
    {complete, rest} = split_events(buffer <> chunk)

    events =
      complete
      |> Enum.map(&parse_event/1)
      |> Enum.reject(&is_nil/1)

    {events, rest}
  end

  defp split_events(data) do
    parts = String.split(data, "\n\n")
    {complete, [rest]} = Enum.split(parts, -1)
    {complete, rest}
  end

  # An SSE event is `event: <name>\ndata: <json>` lines; the JSON's "type"
  # field repeats the event name, so only data lines matter here.
  defp parse_event(raw) do
    raw
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data:"))
    |> Enum.map_join("\n", fn "data:" <> payload -> String.trim_leading(payload) end)
    |> case do
      "" ->
        nil

      json ->
        case Jason.decode(json) do
          {:ok, event} -> event
          {:error, _} -> nil
        end
    end
  end
end
