defmodule Qlarius.Jobs.BackfillMissingSnapshotsWorker do
  @moduledoc """
  Safety net worker that runs periodically to find and fix missing matching_tags_snapshot data.

  This worker:
  1. Finds target_populations with NULL matching_tags_snapshot
  2. Generates and saves the snapshot for each
  3. Finds related offers and ad_events
  4. Replicates the snapshot to those records if they're also NULL

  ## Scheduling

  This worker is scheduled to run every hour via Oban cron in config/config.exs:

      config :qlarius, Oban,
        plugins: [
          {Oban.Plugins.Cron,
           crontab: [
             {"0 * * * *", Qlarius.Jobs.BackfillMissingSnapshotsWorker}
           ]}
        ]

  ## Manual Execution

  To manually trigger a backfill:

      Qlarius.Jobs.BackfillMissingSnapshotsWorker.new(%{})
      |> Oban.insert()
  """

  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.{TargetBand, TargetPopulation}
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  @batch_size 100

  @impl true
  def perform(%Oban.Job{args: _args}) do
    require Logger
    Logger.info("BackfillMissingSnapshotsWorker: Starting snapshot backfill")

    populations_needing_snapshots =
      from(tp in TargetPopulation,
        where: is_nil(tp.matching_tags_snapshot),
        select: %{
          id: tp.id,
          me_file_id: tp.me_file_id,
          target_band_id: tp.target_band_id
        }
      )
      |> Repo.all()

    total = length(populations_needing_snapshots)

    if total > 0 do
      Logger.info(
        "BackfillMissingSnapshotsWorker: Found #{total} populations with missing snapshots"
      )

      populations_needing_snapshots
      |> Enum.chunk_every(@batch_size)
      |> Enum.with_index(1)
      |> Enum.each(fn {batch, batch_num} ->
        Logger.info(
          "BackfillMissingSnapshotsWorker: Processing batch #{batch_num}/#{ceil(total / @batch_size)} (#{length(batch)} records)"
        )

        process_batch(batch)
      end)

      Logger.info(
        "BackfillMissingSnapshotsWorker: ✅ COMPLETE - Fixed #{total} missing snapshots"
      )
    else
      Logger.info("BackfillMissingSnapshotsWorker: No missing snapshots found")
    end

    :ok
  end

  defp process_batch(populations) do
    band_ids = Enum.map(populations, & &1.target_band_id) |> Enum.uniq()

    bands_with_traits =
      from(tb in TargetBand,
        where: tb.id in ^band_ids,
        preload: [trait_groups: :traits]
      )
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    population_updates =
      populations
      |> Enum.map(fn pop ->
        band = bands_with_traits[pop.target_band_id]

        if band do
          trait_metadata = build_trait_metadata(band.trait_groups)
          snapshot = generate_snapshot(pop.me_file_id, trait_metadata)

          if snapshot do
            {pop, snapshot}
          else
            nil
          end
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if population_updates != [] do
      batch_update_populations(population_updates)
      batch_update_offers_and_events(population_updates)
    end
  end

  defp build_trait_metadata(trait_groups) do
    all_traits = Enum.flat_map(trait_groups, fn tg -> tg.traits end)

    parent_ids =
      all_traits
      |> Enum.map(& &1.parent_trait_id)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    parents =
      from(t in Trait,
        where: t.id in ^parent_ids,
        select: %{id: t.id, name: t.trait_name, display_order: t.display_order}
      )
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    all_traits
    |> Enum.group_by(& &1.parent_trait_id)
    |> Enum.map(fn {parent_id, child_traits} ->
      parent = Map.get(parents, parent_id)

      if parent do
        {parent_id,
         %{
           name: parent.name,
           display_order: parent.display_order,
           child_ids: Enum.map(child_traits, & &1.id) |> MapSet.new()
         }}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp generate_snapshot(me_file_id, trait_metadata) do
    me_file_tags =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: mft.me_file_id == ^me_file_id,
        select: %{
          me_file_id: mft.me_file_id,
          trait_id: t.id,
          trait_name: t.trait_name,
          display_order: t.display_order,
          parent_trait_id: t.parent_trait_id,
          tag_value: mft.tag_value
        }
      )
      |> Repo.all()

    build_snapshot(me_file_tags, trait_metadata)
  end

  defp build_snapshot(me_file_tags, trait_metadata) do
    snapshot =
      me_file_tags
      |> Enum.filter(fn tag ->
        Map.has_key?(trait_metadata, tag.parent_trait_id) &&
          MapSet.member?(trait_metadata[tag.parent_trait_id].child_ids, tag.trait_id)
      end)
      |> Enum.group_by(& &1.parent_trait_id)
      |> Enum.map(fn {parent_id, tags} ->
        meta = trait_metadata[parent_id]

        child_tags =
          tags
          |> Enum.map(fn tag ->
            [tag.trait_id, tag.tag_value, tag.display_order]
          end)
          |> Enum.sort_by(fn [_id, _val, order] -> order end)

        [parent_id, meta.name, meta.display_order, child_tags]
      end)
      |> Enum.sort_by(fn [_id, _name, order, _children] -> order end)

    case snapshot do
      [] -> nil
      data -> %{tags: data}
    end
  end

  defp batch_update_populations(population_updates) do
    require Logger
    population_ids = Enum.map(population_updates, fn {pop, _snapshot} -> pop.id end)

    Repo.transaction(fn ->
      Enum.each(population_updates, fn {pop, snapshot} ->
        from(tp in TargetPopulation,
          where: tp.id == ^pop.id and is_nil(tp.matching_tags_snapshot)
        )
        |> Repo.update_all(
          set: [
            matching_tags_snapshot: snapshot,
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          ]
        )
      end)
    end)

    Logger.info(
      "BackfillMissingSnapshotsWorker: Updated #{length(population_ids)} population snapshots"
    )
  end

  defp batch_update_offers_and_events(population_updates) do
    require Logger

    me_file_ids = Enum.map(population_updates, fn {pop, _} -> pop.me_file_id end) |> Enum.uniq()
    band_ids = Enum.map(population_updates, fn {pop, _} -> pop.target_band_id end) |> Enum.uniq()

    snapshot_map =
      population_updates
      |> Enum.map(fn {pop, snapshot} ->
        {{pop.me_file_id, pop.target_band_id}, snapshot}
      end)
      |> Map.new()

    offers_to_update =
      from(o in Offer,
        where:
          o.me_file_id in ^me_file_ids and
            o.target_band_id in ^band_ids and
            is_nil(o.matching_tags_snapshot),
        select: %{id: o.id, me_file_id: o.me_file_id, target_band_id: o.target_band_id}
      )
      |> Repo.all()

    events_to_update =
      from(ae in AdEvent,
        where:
          ae.me_file_id in ^me_file_ids and
            ae.target_band_id in ^band_ids and
            is_nil(ae.matching_tags_snapshot),
        select: %{id: ae.id, me_file_id: ae.me_file_id, target_band_id: ae.target_band_id}
      )
      |> Repo.all()

    if offers_to_update != [] do
      Repo.transaction(fn ->
        Enum.each(offers_to_update, fn offer ->
          snapshot = Map.get(snapshot_map, {offer.me_file_id, offer.target_band_id})

          if snapshot do
            from(o in Offer, where: o.id == ^offer.id)
            |> Repo.update_all(set: [matching_tags_snapshot: snapshot])
          end
        end)
      end)

      Logger.info(
        "BackfillMissingSnapshotsWorker: Updated #{length(offers_to_update)} offers with snapshots"
      )
    end

    if events_to_update != [] do
      Repo.transaction(fn ->
        Enum.each(events_to_update, fn event ->
          snapshot = Map.get(snapshot_map, {event.me_file_id, event.target_band_id})

          if snapshot do
            from(ae in AdEvent, where: ae.id == ^event.id)
            |> Repo.update_all(set: [matching_tags_snapshot: snapshot])
          end
        end)
      end)

      Logger.info(
        "BackfillMissingSnapshotsWorker: Updated #{length(events_to_update)} ad_events with snapshots"
      )
    end
  end
end
