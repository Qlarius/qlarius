defmodule Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker do
  @moduledoc """
  One-time worker to fix incorrectly formatted matching_tags_snapshot data.

  This worker identifies and corrects snapshots that were created in the wrong format
  by HandleOfferCompletionWorker before the fix was applied.

  ## Wrong Format (to fix)
  ```
  %{
    "tags" => [
      %{"trait_id" => 123, "trait_name" => "Male", "parent_trait_id" => 4}
    ],
    "snapshot_at" => "2025-12-20T..."
  }
  ```

  ## Correct Format
  ```
  %{
    tags: [
      [4, "Sex (Biological)", 1, [[123, "Male", 1]]]
    ]
  }
  ```

  ## Detection
  - Wrong format has string key "snapshot_at"
  - Wrong format has "tags" as string key (not atom)
  - Wrong format "tags" value is list of maps (not nested arrays)

  ## Correction Strategy
  1. Find offers with incorrect format
  2. Lookup corresponding target_population snapshot
  3. Copy correct snapshot from population to offer
  4. Find ad_events for those offers with incorrect format
  5. Copy correct snapshot from population to ad_events

  ## Manual Execution

  To run this fix manually:

      Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker.new(%{})
      |> Oban.insert()

  Or run immediately in console:

      Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker.new(%{})
      |> Oban.insert()
      |> then(fn {:ok, job} -> Oban.drain_queue(queue: :maintenance, with_limit: 1) end)
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.TargetPopulation

  @batch_size 100

  @impl true
  def perform(%Oban.Job{args: _args}) do
    require Logger
    Logger.info("FixIncorrectSnapshotFormatsWorker: Starting snapshot format correction")

    {offers_fixed, events_fixed} = fix_incorrect_snapshots()

    Logger.info(
      "FixIncorrectSnapshotFormatsWorker: ✅ COMPLETE - Fixed #{offers_fixed} offers and #{events_fixed} ad_events"
    )

    :ok
  end

  defp fix_incorrect_snapshots do
    offers_fixed = fix_offers()
    events_fixed = fix_ad_events()

    {offers_fixed, events_fixed}
  end

  defp fix_offers do
    require Logger
    Logger.info("FixIncorrectSnapshotFormatsWorker: Scanning offers for incorrect formats")

    incorrect_offers =
      from(o in Offer,
        where: not is_nil(o.matching_tags_snapshot),
        where: fragment("? \\? 'snapshot_at'", o.matching_tags_snapshot),
        select: %{
          id: o.id,
          me_file_id: o.me_file_id,
          target_band_id: o.target_band_id
        }
      )
      |> Repo.all()

    total = length(incorrect_offers)

    if total > 0 do
      Logger.info(
        "FixIncorrectSnapshotFormatsWorker: Found #{total} offers with incorrect format"
      )

      fixed_count =
        incorrect_offers
        |> Enum.chunk_every(@batch_size)
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {batch, batch_num}, acc ->
          Logger.info(
            "FixIncorrectSnapshotFormatsWorker: Processing offers batch #{batch_num}/#{ceil(total / @batch_size)} (#{length(batch)} records)"
          )

          count = fix_offers_batch(batch)
          acc + count
        end)

      Logger.info(
        "FixIncorrectSnapshotFormatsWorker: Fixed #{fixed_count} offers"
      )

      fixed_count
    else
      Logger.info("FixIncorrectSnapshotFormatsWorker: No incorrectly formatted offers found")
      0
    end
  end

  defp fix_offers_batch(offers) do
    me_file_ids = Enum.map(offers, & &1.me_file_id) |> Enum.uniq()
    band_ids = Enum.map(offers, & &1.target_band_id) |> Enum.uniq()

    populations =
      from(tp in TargetPopulation,
        where:
          tp.me_file_id in ^me_file_ids and
            tp.target_band_id in ^band_ids and
            not is_nil(tp.matching_tags_snapshot),
        select: %{
          me_file_id: tp.me_file_id,
          target_band_id: tp.target_band_id,
          matching_tags_snapshot: tp.matching_tags_snapshot
        }
      )
      |> Repo.all()

    snapshot_map =
      populations
      |> Enum.map(fn pop ->
        {{pop.me_file_id, pop.target_band_id}, pop.matching_tags_snapshot}
      end)
      |> Map.new()

    Repo.transaction(fn ->
      Enum.reduce(offers, 0, fn offer, count ->
        correct_snapshot = Map.get(snapshot_map, {offer.me_file_id, offer.target_band_id})

        if correct_snapshot do
          {updated, _} =
            from(o in Offer,
              where: o.id == ^offer.id
            )
            |> Repo.update_all(set: [matching_tags_snapshot: correct_snapshot])

          count + updated
        else
          count
        end
      end)
    end)
    |> case do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp fix_ad_events do
    require Logger
    Logger.info("FixIncorrectSnapshotFormatsWorker: Scanning ad_events for incorrect formats")

    incorrect_events =
      from(ae in AdEvent,
        where: not is_nil(ae.matching_tags_snapshot),
        where: fragment("? \\? 'snapshot_at'", ae.matching_tags_snapshot),
        select: %{
          id: ae.id,
          me_file_id: ae.me_file_id,
          target_band_id: ae.target_band_id
        }
      )
      |> Repo.all()

    total = length(incorrect_events)

    if total > 0 do
      Logger.info(
        "FixIncorrectSnapshotFormatsWorker: Found #{total} ad_events with incorrect format"
      )

      fixed_count =
        incorrect_events
        |> Enum.chunk_every(@batch_size)
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {batch, batch_num}, acc ->
          Logger.info(
            "FixIncorrectSnapshotFormatsWorker: Processing ad_events batch #{batch_num}/#{ceil(total / @batch_size)} (#{length(batch)} records)"
          )

          count = fix_ad_events_batch(batch)
          acc + count
        end)

      Logger.info(
        "FixIncorrectSnapshotFormatsWorker: Fixed #{fixed_count} ad_events"
      )

      fixed_count
    else
      Logger.info(
        "FixIncorrectSnapshotFormatsWorker: No incorrectly formatted ad_events found"
      )

      0
    end
  end

  defp fix_ad_events_batch(events) do
    me_file_ids = Enum.map(events, & &1.me_file_id) |> Enum.uniq()
    band_ids = Enum.map(events, & &1.target_band_id) |> Enum.uniq()

    populations =
      from(tp in TargetPopulation,
        where:
          tp.me_file_id in ^me_file_ids and
            tp.target_band_id in ^band_ids and
            not is_nil(tp.matching_tags_snapshot),
        select: %{
          me_file_id: tp.me_file_id,
          target_band_id: tp.target_band_id,
          matching_tags_snapshot: tp.matching_tags_snapshot
        }
      )
      |> Repo.all()

    snapshot_map =
      populations
      |> Enum.map(fn pop ->
        {{pop.me_file_id, pop.target_band_id}, pop.matching_tags_snapshot}
      end)
      |> Map.new()

    Repo.transaction(fn ->
      Enum.reduce(events, 0, fn event, count ->
        correct_snapshot = Map.get(snapshot_map, {event.me_file_id, event.target_band_id})

        if correct_snapshot do
          {updated, _} =
            from(ae in AdEvent,
              where: ae.id == ^event.id
            )
            |> Repo.update_all(set: [matching_tags_snapshot: correct_snapshot])

          count + updated
        else
          count
        end
      end)
    end)
    |> case do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end
end
