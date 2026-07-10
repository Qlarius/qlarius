defmodule Qlarius.Jobs.SweepExpiredQaiSessionsWorker do
  @moduledoc """
  Hard-deletes Qai sessions whose fleet clock has run out, messages included.

  Fleeting is the privacy promise, not housekeeping: expired conversations
  must actually leave the database, so this deletes rather than archives.
  Reads already exclude expired sessions, so sweep latency is invisible to
  users.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Qlarius.Qai.Sessions

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Sessions.sweep_expired() do
      0 -> :ok
      count -> Logger.info("SweepExpiredQaiSessionsWorker: deleted #{count} expired sessions")
    end

    :ok
  end
end
