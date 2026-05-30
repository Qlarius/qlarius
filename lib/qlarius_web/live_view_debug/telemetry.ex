defmodule QlariusWeb.LiveViewDebug.Telemetry do
  @moduledoc false

  alias QlariusWeb.LiveViewDebug

  @id "qlarius-lv-debug"

  def attach do
    :telemetry.attach_many(
      @id,
      [
        [:oban, :job, :start],
        [:oban, :job, :stop],
        [:oban, :job, :exception],
        [:oban, :plugin, :stop]
      ],
      &QlariusWeb.LiveViewDebug.Telemetry.handle_event/4,
      nil
    )
  end

  def detach do
    :telemetry.detach(@id)
  end

  def handle_event([:oban, :job, :start], _measure, meta, _config) do
    if LiveViewDebug.enabled?() do
      LiveViewDebug.record("oban_job", %{
        phase: "start",
        worker: worker_name(meta),
        queue: meta[:queue],
        attempt: meta[:attempt]
      })
    end
  end

  def handle_event([:oban, :job, :stop], measure, meta, _config) do
    if LiveViewDebug.enabled?() do
      LiveViewDebug.record("oban_job", %{
        phase: "stop",
        worker: worker_name(meta),
        queue: meta[:queue],
        attempt: meta[:attempt],
        duration_ms: System.convert_time_unit(measure.duration, :native, :millisecond),
        state: meta[:state]
      })
    end
  end

  def handle_event([:oban, :job, :exception], measure, meta, _config) do
    if LiveViewDebug.enabled?() do
      LiveViewDebug.record("oban_job", %{
        phase: "exception",
        worker: worker_name(meta),
        queue: meta[:queue],
        attempt: meta[:attempt],
        duration_ms: System.convert_time_unit(measure.duration, :native, :millisecond),
        kind: meta[:kind],
        reason: inspect(meta[:reason], limit: 5, printable_limit: 200)
      })
    end
  end

  def handle_event([:oban, :plugin, :stop], measure, meta, _config) do
    if LiveViewDebug.enabled?() do
      plugin = meta[:plugin]
      jobs = meta[:jobs] || []

      if plugin == Oban.Plugins.Cron or jobs != [] do
        LiveViewDebug.record("oban_plugin", %{
          plugin: plugin && inspect(plugin),
          duration_ms: System.convert_time_unit(measure.duration, :native, :millisecond),
          jobs: inspect(jobs, limit: 8, printable_limit: 200)
        })
      end
    end
  end

  defp worker_name(%{job: %{worker: worker}}), do: to_string(worker)
  defp worker_name(_), do: "unknown"
end
