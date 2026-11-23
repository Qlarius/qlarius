defmodule Qlarius.Jobs.PruneWidgetServeLogsWorker do
  @moduledoc """
  Deletes widget serve logs older than the retention window. The admin
  dashboard reports at most 90 days, so 180 keeps a margin for one-off
  investigations without growing the table forever.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Qlarius.Sponster.WidgetServeLogs

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case WidgetServeLogs.prune() do
      0 -> :ok
      count -> Logger.info("PruneWidgetServeLogsWorker: deleted #{count} widget serve logs")
    end

    :ok
  end
end
