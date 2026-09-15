defmodule Qlarius.Jobs.SyncMeFileToTargetPopulationsWorker do
  use Oban.Worker,
    queue: :targets,
    max_attempts: 3,
    unique: [period: 120, keys: [:me_file_id], states: [:available, :scheduled]]

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, Target, TargetPopulation, TargetBand}
  alias Qlarius.Tiqit.ContentAudienceTarget
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.Jobs.ReconcileOffersForMeFileWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"me_file_id" => me_file_id} = args}) do
    require Logger
    deleted_trait_ids = Map.get(args, "deleted_trait_ids", [])

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Processing me_file #{me_file_id}, deleted_traits=#{inspect(deleted_trait_ids)}"
    )

    active_targets = get_active_targets()

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Found #{length(active_targets)} active targets"
    )

    {new_populations, removed_populations} =
      sync_populations_for_me_file(me_file_id, active_targets)

    if new_populations != [] or removed_populations != [] do
      Logger.info(
        "SyncMeFileToTargetPopulationsWorker: Added #{length(new_populations)}, removed #{length(removed_populations)} populations"
      )

      ReconcileOffersForMeFileWorker.new(%{me_file_id: me_file_id})
      |> Oban.insert()
    else
      Logger.info(
        "SyncMeFileToTargetPopulationsWorker: No population changes for me_file #{me_file_id}"
      )
    end

    :ok
  end

  # Every target worth keeping populations for: those driving a live campaign,
  # plus those attached to creator content. Content-only audiences never reach a
  # campaign, so keying this off campaigns alone would leave their populations
  # to drift as users retag.
  #
  # Returns distinct targets with bands and traits loaded once, rather than once
  # per referencing campaign — several campaigns commonly share a target.
  defp get_active_targets do
    campaign_target_ids =
      from(c in Campaign,
        where: is_nil(c.deactivated_at) and not is_nil(c.target_id),
        select: c.target_id
      )

    content_target_ids = from(a in ContentAudienceTarget, select: a.target_id)

    from(t in Target,
      where: t.id in subquery(campaign_target_ids) or t.id in subquery(content_target_ids),
      preload: [target_bands: [trait_groups: :traits]]
    )
    |> Repo.all()
  end

  defp sync_populations_for_me_file(me_file_id, targets) do
    # Trait-group membership checks dominate this worker, and the same group
    # recurs across bands, across targets and across every copy of an audience.
    # Memoize on the trait id set so identical groups cost one query, not one
    # per occurrence.
    {optimal_bands_by_target, _cache} =
      Enum.reduce(targets, {%{}, %{}}, fn target, {acc, cache} ->
        {optimal_band, cache} = find_optimal_band_for_me_file(target, me_file_id, cache)

        if optimal_band do
          {Map.put(acc, target.id, optimal_band.id), cache}
        else
          {acc, cache}
        end
      end)

    all_band_ids = Map.values(optimal_bands_by_target) |> MapSet.new()

    existing_population_band_ids =
      from(tp in TargetPopulation,
        where: tp.me_file_id == ^me_file_id,
        select: tp.target_band_id
      )
      |> Repo.all()
      |> MapSet.new()

    bands_to_add =
      MapSet.difference(all_band_ids, existing_population_band_ids) |> MapSet.to_list()

    bands_to_remove =
      MapSet.difference(existing_population_band_ids, all_band_ids) |> MapSet.to_list()

    if bands_to_add != [] do
      insert_target_populations_with_snapshots(me_file_id, bands_to_add)
    end

    if bands_to_remove != [] do
      delete_target_populations(me_file_id, bands_to_remove)
    end

    {bands_to_add, bands_to_remove}
  end

  # Bands are checked most-restrictive first and the first match wins, so the
  # me_file lands in its innermost qualifying band — the same rule
  # PopulateTargetWorker applies in batch.
  defp find_optimal_band_for_me_file(target, me_file_id, cache) do
    target.target_bands
    |> Enum.sort_by(&length(&1.trait_groups), :desc)
    |> Enum.reduce_while({nil, cache}, fn band, {_none, cache} ->
      case me_file_matches_band?(me_file_id, band, cache) do
        {true, cache} -> {:halt, {band, cache}}
        {false, cache} -> {:cont, {nil, cache}}
      end
    end)
  end

  defp me_file_matches_band?(_me_file_id, %{trait_groups: []}, cache), do: {false, cache}

  defp me_file_matches_band?(me_file_id, band, cache) do
    Enum.reduce_while(band.trait_groups, {true, cache}, fn trait_group, {_so_far, cache} ->
      case me_file_has_trait_from_group?(me_file_id, trait_group, cache) do
        {true, cache} -> {:cont, {true, cache}}
        {false, cache} -> {:halt, {false, cache}}
      end
    end)
  end

  defp me_file_has_trait_from_group?(me_file_id, trait_group, cache) do
    trait_ids = trait_group.traits |> Enum.map(& &1.id) |> Enum.sort()

    cond do
      trait_ids == [] ->
        {false, cache}

      Map.has_key?(cache, trait_ids) ->
        {Map.fetch!(cache, trait_ids), cache}

      true ->
        matches =
          from(mft in MeFileTag,
            where: mft.me_file_id == ^me_file_id and mft.trait_id in ^trait_ids
          )
          |> Repo.exists?()

        {matches, Map.put(cache, trait_ids, matches)}
    end
  end

  defp insert_target_populations_with_snapshots(me_file_id, band_ids) do
    require Logger
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Load bands with trait_groups
    bands =
      from(tb in TargetBand,
        where: tb.id in ^band_ids,
        preload: [trait_groups: :traits]
      )
      |> Repo.all()

    # Build trait metadata for each band
    trait_metadata_by_band =
      bands
      |> Enum.map(fn band ->
        trait_metadata = build_trait_metadata(band.trait_groups)
        {band.id, trait_metadata}
      end)
      |> Map.new()

    # Fetch me_file_tags for this me_file
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

    # Build inserts with snapshots
    inserts =
      Enum.map(band_ids, fn band_id ->
        trait_metadata = Map.get(trait_metadata_by_band, band_id, %{})
        snapshot = build_snapshot(me_file_tags, trait_metadata)

        %{
          me_file_id: me_file_id,
          target_band_id: band_id,
          matching_tags_snapshot: snapshot,
          created_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(TargetPopulation, inserts,
        on_conflict: :nothing,
        conflict_target: [:target_band_id, :me_file_id]
      )

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Inserted #{count} new populations with snapshots for me_file #{me_file_id}"
    )
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

  defp delete_target_populations(me_file_id, band_ids) do
    require Logger

    {count, _} =
      from(tp in TargetPopulation,
        where: tp.me_file_id == ^me_file_id,
        where: tp.target_band_id in ^band_ids
      )
      |> Repo.delete_all()

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Deleted #{count} populations for me_file #{me_file_id}"
    )
  end
end
