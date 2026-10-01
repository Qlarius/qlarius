defmodule Qlarius.Jobs.SyncContentGroupFeedsWorker do
  @moduledoc """
  Daily sync of content groups that have a podcast feed with daily sync on.
  Each group syncs on its own, so one broken feed doesn't stop the rest.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Qlarius.Tiqit.Arcade.RssImporter

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Enum.each(RssImporter.auto_sync_groups(), &sync/1)
  end

  defp sync(group) do
    case RssImporter.sync_group(group) do
      {:ok, %{counts: %{created: 0}}} ->
        :ok

      {:ok, %{counts: %{created: created}}} ->
        Logger.info("SyncContentGroupFeedsWorker: group #{group.id} added #{created} episodes")

      {:error, reason} ->
        Logger.warning(
          "SyncContentGroupFeedsWorker: group #{group.id} failed: #{inspect(reason)}"
        )
    end
  rescue
    error ->
      Logger.error(
        "SyncContentGroupFeedsWorker: group #{group.id} crashed: #{Exception.message(error)}"
      )
  end
end
