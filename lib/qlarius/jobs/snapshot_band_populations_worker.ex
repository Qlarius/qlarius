defmodule Qlarius.Jobs.SnapshotBandPopulationsWorker do
  @moduledoc """
  **DEPRECATED FOR NEW POPULATIONS** - Snapshots are now created inline during PopulateTargetWorker.
  
  This worker is only used for backfilling matching_tags_snapshot for legacy target_populations
  that were created before inline snapshot creation was implemented.

  Creates matching_tags_snapshot for all target_populations in a given target_band that have
  NULL snapshots. The snapshot includes all tags from the me_file that match the band's
  trait_groups, formatted as nested arrays for JSONB storage.

  ## Manual Execution (for backfilling legacy data)

  To manually snapshot all populations for a specific band:

      # In IEx console:
      Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: 123})
      |> Oban.insert()

  To snapshot all bands in a target:

      target_id = 60
      Qlarius.Repo.all(
        from tb in Qlarius.Sponster.Campaigns.TargetBand,
        where: tb.target_id == ^target_id,
        select: tb.id
      )
      |> Enum.each(fn band_id ->
        Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: band_id})
        |> Oban.insert()
      end)
  """

  use Oban.Worker, queue: :targets, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{TargetBand, TargetPopulation}
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  @batch_size 500

  @impl true
  def perform(%Oban.Job{args: %{"band_id" => band_id}}) do
    require Logger
    Logger.info("SnapshotBandPopulationsWorker: Starting for band_id=#{band_id}")

    band = Repo.get!(TargetBand, band_id) |> Repo.preload(trait_groups: :traits)
    trait_metadata = build_trait_metadata(band.trait_groups)

    populations =
      from(tp in TargetPopulation,
        where: tp.target_band_id == ^band_id and is_nil(tp.matching_tags_snapshot),
        select: %{id: tp.id, me_file_id: tp.me_file_id}
      )
      |> Repo.all()

    total = length(populations)
    Logger.info("SnapshotBandPopulationsWorker: Found #{total} populations needing snapshots")

    if total > 0 do
      populations
      |> Enum.chunk_every(@batch_size)
      |> Enum.with_index(1)
      |> Enum.each(fn {batch, batch_num} ->
        Logger.info(
          "SnapshotBandPopulationsWorker: Processing batch #{batch_num}/#{ceil(total / @batch_size)} (#{length(batch)} records)"
        )

        process_batch(batch, trait_metadata)
      end)
    end

    Logger.info("SnapshotBandPopulationsWorker: ✅ COMPLETE for band_id=#{band_id}")
    :ok
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

  defp process_batch(populations, trait_metadata) do
    me_file_ids = Enum.map(populations, & &1.me_file_id)

    me_file_tags_grouped =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: mft.me_file_id in ^me_file_ids,
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
      |> Enum.group_by(& &1.me_file_id)

    updates =
      Enum.map(populations, fn pop ->
        me_file_tags = Map.get(me_file_tags_grouped, pop.me_file_id, [])
        snapshot = build_snapshot(me_file_tags, trait_metadata)

        %{
          id: pop.id,
          matching_tags_snapshot: snapshot,
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

    Repo.insert_all(
      TargetPopulation,
      updates,
      on_conflict: {:replace, [:matching_tags_snapshot, :updated_at]},
      conflict_target: [:id]
    )
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

    # Always return a map structure, even for empty snapshots
    # This distinguishes "checked with no matches" from "never checked" (NULL)
    %{tags: snapshot}
  end
end
