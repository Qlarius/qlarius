defmodule Qlarius.Jobs.DeactivateEndedCampaignsWorker do
  @moduledoc """
  Deactivates launched campaigns whose `end_date` has passed.

  Uses `Campaigns.deactivate_campaign/1`, the same path as a manual stop, so the
  campaign's offers are deleted and ad counts, totals and notifications stop
  including it.
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  require Logger

  alias Qlarius.Sponster.Campaigns

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    ended = Campaigns.list_ended_active_campaigns(now)

    if ended != [] do
      Logger.info("DeactivateEndedCampaignsWorker: deactivating #{length(ended)} ended campaigns")

      Enum.each(ended, fn campaign ->
        case Campaigns.deactivate_campaign(campaign) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "DeactivateEndedCampaignsWorker: failed to deactivate campaign #{campaign.id}: #{inspect(reason)}"
            )
        end
      end)
    end

    :ok
  end
end
