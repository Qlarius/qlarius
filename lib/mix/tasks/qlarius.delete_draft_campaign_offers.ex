defmodule Mix.Tasks.Qlarius.DeleteDraftCampaignOffers do
  @moduledoc """
  Deletes offers whose campaign has never launched (`launched_at` is null).

  Offers that already have an ad event are left alone and counted in the
  output. Do not run this against production until that run is approved.

      mix qlarius.delete_draft_campaign_offers
  """

  use Mix.Task

  @shortdoc "Delete offers on campaigns that have not launched"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{deleted: deleted, kept_with_events: kept} =
      Qlarius.Sponster.DraftOfferCleanup.delete_unlaunched_offers()

    IO.puts("deleted=#{deleted}")
    IO.puts("kept_with_events=#{kept}")
  end
end
