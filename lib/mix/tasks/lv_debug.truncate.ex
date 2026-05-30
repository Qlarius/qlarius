defmodule Mix.Tasks.LvDebug.Truncate do
  @moduledoc """
  Archive and clear the LiveView debug log (useful when it grows large).

      mix lv_debug.truncate
  """
  use Mix.Task

  @shortdoc "Archive and clear tmp/lv_debug.ndjson"

  @impl Mix.Task
  def run(_args) do
    path = QlariusWeb.LiveViewDebug.log_path()

    unless File.exists?(path) do
      Mix.shell().info("No log at #{path}")
      :ok
    else
      {:ok, stat} = File.stat(path)
      archived = path <> ".#{DateTime.utc_now() |> DateTime.to_iso8601(:basic)}.bak"

      File.rename!(path, archived)

      Mix.shell().info(
        "Archived #{byte_size_human(stat.size)} to #{archived}. A fresh log will be created on the next event."
      )
    end
  end

  defp byte_size_human(bytes) when bytes >= 1_048_576,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp byte_size_human(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp byte_size_human(bytes), do: "#{bytes} B"
end
