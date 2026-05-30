defmodule QlariusWeb.LiveViewDebug.CodeReloaderPlug do
  @moduledoc false

  @behaviour Plug

  alias QlariusWeb.LiveViewDebug

  @compile_threshold_ms 25

  @impl Plug
  def init(opts), do: Phoenix.CodeReloader.init(opts)

  @impl Plug
  def call(conn, opts) do
    endpoint = conn.private.phoenix_endpoint
    debug? = LiveViewDebug.enabled?()
    manifest_before = if(debug?, do: manifest_version(), else: nil)
    started = System.monotonic_time(:millisecond)

    result = Phoenix.CodeReloader.reload(endpoint, opts)

    if debug? do
      duration_ms = System.monotonic_time(:millisecond) - started
      manifest_after = manifest_version()

      if should_log?(result, duration_ms, manifest_before, manifest_after) do
        LiveViewDebug.record("code_reloader", %{
          result: format_result(result),
          path: conn.request_path,
          method: conn.method,
          duration_ms: duration_ms,
          manifest_changed: manifest_before != manifest_after,
          conn_pid: inspect(self())
        })
      end
    end

    Phoenix.CodeReloader.call(
      conn,
      Keyword.put(opts, :reloader, fn _endpoint, _opts -> result end)
    )
  end

  defp should_log?(:ok, duration_ms, before, after_v) do
    duration_ms >= @compile_threshold_ms or before != after_v
  end

  defp should_log?({:error, _}, _duration_ms, _before, _after_v), do: true

  defp format_result(:ok), do: "ok"
  defp format_result({:error, output}), do: "error: #{String.slice(to_string(output), 0, 200)}"

  defp manifest_version do
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
