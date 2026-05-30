defmodule QlariusWeb.LiveViewDebug do
  @moduledoc """
  Opt-in LiveView lifecycle logging to trace unexpected remounts and assign refreshes.

  Dev: `config :qlarius, QlariusWeb.LiveViewDebug, enabled: true`

  Events append to `tmp/lv_debug.ndjson` (one JSON object per line). After a refresh,
  run `mix lv_debug.recent` or ask the agent to search that file.

  Server-side triggers also logged when enabled:

  * `build_manifest_changed` — compile manifest updated (often a background `mix compile`)
  * `code_reloader` — Phoenix recompiled or purged beams on an HTTP request
  * `oban_job` / `oban_plugin` — background job activity near socket drops

  Each browser tab gets a `tab_id` (sessionStorage) so client + server lines correlate.
  """

  require Logger

  @wallet_sync_mod QlariusWeb.WalletBalanceSync
  @default_log_path "tmp/lv_debug.ndjson"
  @default_max_log_bytes 20 * 1024 * 1024

  def attach! do
    if enabled?() do
      QlariusWeb.LiveViewDebug.Telemetry.attach()
    end

    :ok
  end

  def children do
    if enabled?() do
      [QlariusWeb.LiveViewDebug.BuildWatcher]
    else
      []
    end
  end

  def max_log_bytes do
    Application.get_env(:qlarius, __MODULE__, [])
    |> Keyword.get(:max_log_bytes, @default_max_log_bytes)
  end

  def enabled? do
    Application.get_env(:qlarius, __MODULE__, [])
    |> Keyword.get(:enabled, false)
  end

  def log_path do
    Application.get_env(:qlarius, __MODULE__, [])
    |> Keyword.get(:log_path, @default_log_path)
    |> Path.expand()
  end

  @doc "Append a structured event to the NDJSON log and mirror a one-line summary to Logger."
  def record(type, fields \\ %{}) when is_binary(type) and is_map(fields) do
    if enabled?() do
      entry =
        %{
          ts: DateTime.utc_now() |> DateTime.to_iso8601(:extended),
          ms: System.monotonic_time(:millisecond),
          type: type
        }
        |> Map.merge(stringify_keys(fields))

      persist(entry)
      Logger.info("[LV debug] #{type} #{summarize(entry)}")
    end

    :ok
  end

  def log_mount(socket) do
    kind =
      cond do
        not Phoenix.LiveView.connected?(socket) -> "static"
        Map.get(socket.assigns, :mounted) == true -> "reconnect"
        true -> "connect"
      end

    record("mount", %{
      view: inspect(socket.view),
      kind: kind,
      nested?: nested_live_view?(socket),
      pid: inspect(self()),
      parent_pid: inspect(socket.parent_pid),
      lv_id: if(connected?(socket), do: socket.id, else: nil),
      path: mount_path(socket),
      scope?: scope_present?(socket)
    })

    socket
  end

  def log_handle_info(socket, msg) do
    record("handle_info", %{
      view: inspect(socket.view),
      pid: inspect(self()),
      lv_id: socket.id,
      msg: inspect(msg, limit: 8, printable_limit: 200)
    })
  end

  def log_wallet_sync(socket, msg) do
    record("wallet_sync", %{
      view: inspect(socket.view),
      pid: inspect(self()),
      lv_id: socket.id,
      msg: inspect(msg, limit: 5, printable_limit: 120)
    })
  end

  def log_wallet_subscribe(socket, action) do
    record("wallet_subscribe", %{
      view: inspect(socket.view),
      pid: inspect(self()),
      action: action
    })
  end

  def record_client(params) when is_map(params) do
    record("client", %{
      tab_id: Map.get(params, "tab_id") || Map.get(params, :tab_id),
      client_type: Map.get(params, "type") || Map.get(params, :type),
      url: Map.get(params, "url") || Map.get(params, :url),
      detail: normalize_client_detail(Map.get(params, "detail") || Map.get(params, :detail))
    })
  end

  def wallet_sync_message?(msg), do: @wallet_sync_mod.sync_message?(msg)

  defp connected?(socket), do: Phoenix.LiveView.connected?(socket)

  defp mount_path(socket) do
    cond do
      nested_live_view?(socket) ->
        socket.assigns[:current_path]

      true ->
        case Phoenix.LiveView.get_connect_info(socket, :uri) do
          %URI{path: path} when is_binary(path) -> path
          _ -> socket.assigns[:current_path]
        end
    end
  end

  defp nested_live_view?(socket) do
    match?(%{parent_pid: pid} when is_pid(pid), socket)
  end

  defp scope_present?(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} when is_integer(id) -> true
      _ -> false
    end
  end

  defp persist(entry) do
    path = log_path()
    File.mkdir_p!(Path.dirname(path))
    maybe_rotate(path)
    File.write!(path, Jason.encode!(entry) <> "\n", [:append])
  rescue
    e ->
      Logger.warning("[LV debug] failed to write #{log_path()}: #{Exception.message(e)}")
  end

  defp maybe_rotate(path) do
    max_bytes = max_log_bytes()

    case File.stat(path) do
      {:ok, %{size: size}} when size >= max_bytes ->
        rotate_log(path)

      _ ->
        :ok
    end
  end

  defp rotate_log(path) do
    rotated = path <> ".1"

    File.rm(rotated)
    File.rename(path, rotated)

    record("log_rotated", %{
      archived: rotated,
      max_bytes: max_log_bytes()
    })
  rescue
    e ->
      Logger.warning("[LV debug] log rotation failed: #{Exception.message(e)}")
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_value(v)}
      {k, v} -> {k, stringify_value(v)}
    end)
  end

  defp stringify_value(v) when is_binary(v) or is_nil(v) or is_boolean(v) or is_number(v), do: v
  defp stringify_value(v), do: inspect(v, limit: 8, printable_limit: 200)

  defp normalize_client_detail(nil), do: nil
  defp normalize_client_detail(d) when is_map(d), do: d
  defp normalize_client_detail(d), do: inspect(d, limit: 5, printable_limit: 200)

  defp summarize(%{"type" => type} = entry) do
    rest =
      entry
      |> Map.drop(["ts", "ms", "type"])
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join(" ")

    if rest == "", do: type, else: "#{type} #{rest}"
  end

  defp summarize(entry), do: inspect(entry, limit: 5)
end
