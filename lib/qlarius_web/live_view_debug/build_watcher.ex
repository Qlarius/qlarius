defmodule QlariusWeb.LiveViewDebug.BuildWatcher do
  @moduledoc false

  use GenServer

  alias QlariusWeb.LiveViewDebug

  @interval_ms 2_000

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_tick()
    {:ok, Map.put(state, :last, manifest_fingerprint())}
  end

  @impl true
  def handle_info(:tick, %{last: last} = state) do
    current = manifest_fingerprint()

    if is_binary(last) and current != last do
      LiveViewDebug.record("build_manifest_changed", %{
        source: "build_watcher",
        before: last,
        manifest_after: current
      })
    end

    schedule_tick()
    {:noreply, %{state | last: current}}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @interval_ms)
  end

  defp manifest_fingerprint do
    if Code.ensure_loaded?(Mix.Project) do
      Mix.Tasks.Compile.Elixir.manifests()
      |> Enum.map(fn path ->
        case File.stat(path) do
          {:ok, stat} -> {path, stat.mtime, stat.size}
          _ -> {path, nil, nil}
        end
      end)
      |> inspect()
    else
      "mix_unavailable"
    end
  end
end
