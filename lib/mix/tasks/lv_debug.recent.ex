defmodule Mix.Tasks.LvDebug.Recent do
  @moduledoc """
  Print recent LiveView debug events from `tmp/lv_debug.ndjson`.

      mix lv_debug.recent
      mix lv_debug.recent 100
      mix lv_debug.recent --tab TAB_ID
      mix lv_debug.recent --type build_manifest_changed
      mix lv_debug.recent --server
  """
  use Mix.Task

  @shortdoc "Show recent LiveView debug NDJSON log entries"

  @server_types ~w(
    build_manifest_changed
    code_reloader
    oban_job
    oban_plugin
    log_rotated
  )

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [tab: :string, type: :string, server: :boolean]
      )

    n = rest |> List.first() |> parse_count()

    path = QlariusWeb.LiveViewDebug.log_path()

    unless File.exists?(path) do
      Mix.shell().info("No log at #{path} (enable LiveViewDebug in dev and reproduce a refresh)")
      :ok
    else
      {:ok, stat} = File.stat(path)

      Mix.shell().info(
        "Log: #{path} (#{byte_size_human(stat.size)}). Server types: #{Enum.join(@server_types, ", ")}"
      )

      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> maybe_filter_tab(opts[:tab])
      |> maybe_filter_type(opts[:type], opts[:server])
      |> Enum.take(-n)
      |> Enum.each(&print_line/1)
    end
  end

  defp parse_count(nil), do: 50
  defp parse_count(str) when is_binary(str), do: String.to_integer(str)

  defp maybe_filter_tab(lines, nil), do: lines

  defp maybe_filter_tab(lines, tab_id) do
    Enum.filter(lines, fn line ->
      case Jason.decode(line) do
        {:ok, %{"tab_id" => ^tab_id}} -> true
        {:ok, map} -> String.contains?(Jason.encode!(map), tab_id)
        _ -> false
      end
    end)
  end

  defp maybe_filter_type(lines, type, _server) when is_binary(type) do
    Enum.filter(lines, fn line ->
      match?({:ok, %{"type" => ^type}}, Jason.decode(line))
    end)
  end

  defp maybe_filter_type(lines, _type, true) do
    Enum.filter(lines, fn line ->
      case Jason.decode(line) do
        {:ok, %{"type" => type}} when type in @server_types -> true
        _ -> false
      end
    end)
  end

  defp maybe_filter_type(lines, _type, _), do: lines

  defp print_line(line) do
    case Jason.decode(line) do
      {:ok, map} ->
        ts = Map.get(map, "ts", "?")
        type = Map.get(map, "type", "?")
        rest = Map.drop(map, ["ts", "ms", "type"])
        fields = Enum.map_join(rest, " ", fn {k, v} -> "#{k}=#{v}" end)
        Mix.shell().info("#{ts} [#{type}] #{fields}")

      _ ->
        Mix.shell().info(line)
    end
  end

  defp byte_size_human(bytes) when bytes >= 1_048_576,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp byte_size_human(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp byte_size_human(bytes), do: "#{bytes} B"
end
