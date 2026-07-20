defmodule Qlarius.Jobs.HandleOfferCompletionWorker do
  use Oban.Worker, queue: :offers, max_attempts: 3

  alias Qlarius.Sponster.OfferCompletion

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"offer_id" => offer_id, "completed_at" => completed_at_string}}) do
    require Logger
    Logger.info("HandleOfferCompletionWorker: Processing offer #{offer_id}")

    completed_at = NaiveDateTime.from_iso8601!(completed_at_string)

    case OfferCompletion.finalize(offer_id, completed_at) do
      {:ok, :already_finalized} ->
        Logger.info(
          "HandleOfferCompletionWorker: Offer #{offer_id} no longer exists (already deleted), skipping"
        )

        :ok

      {:ok, :run_complete} ->
        Logger.info("HandleOfferCompletionWorker: Media run complete, deleted final offer #{offer_id}")
        :ok

      {:ok, {:next_offer, new_offer}} ->
        Logger.info(
          "HandleOfferCompletionWorker: Created next offer #{new_offer.id} for me_file #{new_offer.me_file_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "HandleOfferCompletionWorker: Failed to finalize offer #{offer_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
