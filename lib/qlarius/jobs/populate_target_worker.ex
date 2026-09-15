defmodule Qlarius.Jobs.PopulateTargetWorker do
  use Oban.Worker, queue: :targets, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo

  alias Qlarius.Sponster.Campaigns.{
    BandDefinition,
    CampaignPubSub,
    Target,
    TargetBand,
    TargetPopulation,
    Targets
  }

  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait

  @batch_size 500

  @impl true
  def perform(%Oban.Job{args: %{"target_id" => target_id}}) do
    require Logger
    Logger.info("PopulateTargetWorker: Starting for target_id=#{target_id}")

    target = Repo.get!(Target, target_id)
    bands = Targets.get_bands_for_target(target_id)
    Logger.info("PopulateTargetWorker: Found #{length(bands)} bands for target #{target_id}")

    if bands == [] do
      Logger.warning("PopulateTargetWorker: No bands found for target #{target_id}, aborting")
      Targets.update_target(target, %{population_status: "not_populated"})
      {:ok, :no_bands}
    else
      sorted_bands = Enum.sort_by(bands, &length(&1.trait_groups))

      Enum.each(sorted_bands, fn band ->
        Logger.info(
          "  Band #{band.id} (#{if band.is_bullseye == "1", do: "Bullseye", else: "Ring"}): #{length(band.trait_groups)} trait_groups"
        )
      end)

      # Recomputed fresh every run, so a hash that drifted since the last
      # populate costs a missed optimization rather than producing wrong rows.
      hashes_by_band = refresh_band_metadata(sorted_bands)

      case populate_by_copy(target_id, sorted_bands, hashes_by_band) do
        {:ok, copied} ->
          Logger.info(
            "PopulateTargetWorker: Reused an existing population, copied #{copied} rows"
          )

          finish_populating(target, sorted_bands)
          {:ok, :copied}

        :no_twin ->
          populate_by_scan(target, target_id, bands, sorted_bands)
      end
    end
  end

  defp populate_by_scan(target, target_id, bands, sorted_bands) do
    require Logger

    existing_populations =
      from(tp in TargetPopulation,
        join: tb in TargetBand,
        on: tp.target_band_id == tb.id,
        where: tb.target_id == ^target_id,
        select: {tp.me_file_id, tp.target_band_id}
      )
      |> Repo.all()
      |> MapSet.new()

    Logger.info(
      "PopulateTargetWorker: Found #{MapSet.size(existing_populations)} existing populations"
    )

    new_populations = populate_bands_bottom_up(sorted_bands)

    Logger.info("PopulateTargetWorker: Calculated #{map_size(new_populations)} new populations")

    {populations_to_insert, populations_to_delete} =
      calculate_population_changes(new_populations, existing_populations)

    Logger.info(
      "PopulateTargetWorker: #{length(populations_to_insert)} to insert, #{length(populations_to_delete)} to delete"
    )

    if populations_to_delete != [] do
      delete_conditions =
        Enum.map(populations_to_delete, fn {mf_id, band_id} ->
          dynamic([tp], tp.me_file_id == ^mf_id and tp.target_band_id == ^band_id)
        end)

      delete_query =
        Enum.reduce(delete_conditions, false, fn condition, acc ->
          dynamic([], ^acc or ^condition)
        end)

      {deleted_count, _} =
        from(tp in TargetPopulation, where: ^delete_query)
        |> Repo.delete_all()

      Logger.info("PopulateTargetWorker: Deleted #{deleted_count} populations")
    end

    if populations_to_insert != [] do
      Logger.info("PopulateTargetWorker: Building snapshots and inserting populations...")
      trait_metadata_by_band = build_trait_metadata_for_bands(bands)

      total_inserted =
        populations_to_insert
        |> Enum.chunk_every(@batch_size)
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {batch, batch_num}, acc ->
          Logger.info(
            "PopulateTargetWorker: Processing batch #{batch_num}/#{ceil(length(populations_to_insert) / @batch_size)} (#{length(batch)} populations)"
          )

          count = insert_populations_with_snapshots(batch, trait_metadata_by_band)
          acc + count
        end)

      Logger.info("PopulateTargetWorker: Inserted #{total_inserted} populations with snapshots")
    end

    finish_populating(target, sorted_bands)

    {:ok, :scanned}
  end

  defp finish_populating(target, bands) do
    require Logger

    refresh_population_counts(bands)

    Targets.update_target(target, %{
      population_status: "populated",
      last_populated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })

    timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.to_string()
    Logger.info("PopulateTargetWorker: ✅ COMPLETE for target_id=#{target.id} at #{timestamp}")

    Phoenix.PubSub.broadcast(
      Qlarius.PubSub,
      "targets",
      {:target_populated, target.id, timestamp}
    )

    broadcast_to_campaigns_using_target(target.id)
  end

  # --- Population reuse by content fingerprint ---

  # `tier` and `definition_hash` are both caches derived from band structure, and
  # both are refreshed here rather than when bands are edited. Population is only
  # ever triggered explicitly (`Targets.trigger_population/1`), so between edits
  # and the next populate these columns describe the structure the population
  # rows were computed against — which is the state any reader of those rows
  # wants. Bands created since the last populate carry a nil tier.
  #
  # Ordering matches the backfill in
  # 20260915043240_add_ranking_fields_to_target_bands.exs: most trait groups
  # first, id as tiebreak, so tier 0 is the most restrictive band.
  defp refresh_band_metadata(bands) do
    bands
    |> Enum.sort_by(fn band -> {-length(band.trait_groups), band.id} end)
    |> Enum.with_index()
    |> Map.new(fn {band, tier} ->
      hash = BandDefinition.hash_for_band(band)

      from(tb in TargetBand, where: tb.id == ^band.id)
      |> Repo.update_all(set: [tier: tier, definition_hash: hash])

      {band.id, hash}
    end)
  end

  defp refresh_population_counts(bands) do
    counts =
      from(tp in TargetPopulation,
        where: tp.target_band_id in ^Enum.map(bands, & &1.id),
        group_by: tp.target_band_id,
        select: {tp.target_band_id, count(tp.id)}
      )
      |> Repo.all()
      |> Map.new()

    # Note this counts rows in `target_populations`, which records only each
    # me_file's *innermost* matching band. So it is "me_files whose best match
    # is this band", not "everyone who satisfies this band's criteria" — the
    # latter would double-count people assigned to narrower bands. Selectivity
    # ranking wants the former.
    Enum.each(bands, fn band ->
      from(tb in TargetBand, where: tb.id == ^band.id)
      |> Repo.update_all(set: [population_count: Map.get(counts, band.id, 0)])
    end)
  end

  # Populates by copying another target's rows when the whole band set is
  # content-identical.
  #
  # Reuse is all-or-nothing across the band set, never per band. A population
  # row records only the me_file's innermost matching band, so that assignment
  # is a property of the *set* — importing one band's rows in isolation would
  # bring over an assignment computed against a different set of rings. Partial
  # overlap therefore falls back to the normal scan.
  defp populate_by_copy(target_id, bands, hashes_by_band) do
    require Logger

    our_hashes = Enum.map(bands, &Map.get(hashes_by_band, &1.id))

    if not BandDefinition.reusable?(our_hashes) do
      :no_twin
    else
      case find_twin_target(target_id, our_hashes) do
        nil ->
          :no_twin

        source_bands_by_hash ->
          our_bands_by_hash = Map.new(bands, &{Map.get(hashes_by_band, &1.id), &1.id})
          copy_populations(target_id, our_bands_by_hash, source_bands_by_hash)
      end
    end
  end

  # Finds a populated target whose band set fingerprints identically, verifying
  # the candidate by recomputing its hashes rather than trusting the stored
  # column, which can be stale. Returns a hash => band_id map for the winner.
  defp find_twin_target(target_id, our_hashes) do
    wanted = Enum.sort(our_hashes)

    candidate_ids =
      from(tb in TargetBand,
        join: t in Target,
        on: t.id == tb.target_id,
        where:
          tb.target_id != ^target_id and
            t.population_status == "populated" and
            tb.definition_hash in ^our_hashes,
        distinct: true,
        select: tb.target_id
      )
      |> Repo.all()

    candidate_ids
    |> Enum.find_value(fn candidate_id ->
      candidate_bands =
        from(tb in TargetBand,
          where: tb.target_id == ^candidate_id,
          preload: [trait_groups: :traits]
        )
        |> Repo.all()

      fresh = Map.new(candidate_bands, &{&1.id, BandDefinition.hash_for_band(&1)})
      fresh_hashes = Map.values(fresh)

      if BandDefinition.reusable?(fresh_hashes) and Enum.sort(fresh_hashes) == wanted do
        Map.new(fresh, fn {band_id, hash} -> {hash, band_id} end)
      end
    end)
  end

  defp copy_populations(target_id, our_bands_by_hash, source_bands_by_hash) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Replace wholesale rather than diffing. Reuse only runs when a target is
    # being populated, so any rows already present were computed against a band
    # set we are about to supersede.
    from(tp in TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id
    )
    |> Repo.delete_all()

    copied =
      Enum.reduce(our_bands_by_hash, 0, fn {hash, our_band_id}, acc ->
        source_band_id = Map.fetch!(source_bands_by_hash, hash)

        # INSERT ... SELECT, so no population rows travel through the app. The
        # snapshot copies verbatim because it is content-determined: identical
        # trait id sets yield identical parent/child metadata.
        source =
          from(tp in TargetPopulation,
            where: tp.target_band_id == ^source_band_id,
            select: %{
              me_file_id: tp.me_file_id,
              target_band_id: type(^our_band_id, :integer),
              matching_tags_snapshot: tp.matching_tags_snapshot,
              created_at: type(^now, :naive_datetime),
              updated_at: type(^now, :naive_datetime)
            }
          )

        {count, _} =
          Repo.insert_all(TargetPopulation, source,
            on_conflict: :nothing,
            conflict_target: [:target_band_id, :me_file_id]
          )

        acc + count
      end)

    {:ok, copied}
  end

  defp build_trait_metadata_for_bands(bands) do
    require Logger
    Logger.info("PopulateTargetWorker: Building trait metadata for #{length(bands)} bands")

    bands
    |> Enum.map(fn band ->
      band = Repo.preload(band, trait_groups: :traits)
      trait_metadata = build_trait_metadata(band.trait_groups)
      {band.id, trait_metadata}
    end)
    |> Map.new()
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

  defp insert_populations_with_snapshots(batch, trait_metadata_by_band) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    me_file_ids = Enum.map(batch, fn {me_file_id, _band_id} -> me_file_id end) |> Enum.uniq()

    # Fetch all me_file_tags for this batch
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

    # Build inserts with snapshots
    inserts =
      Enum.map(batch, fn {me_file_id, band_id} ->
        me_file_tags = Map.get(me_file_tags_grouped, me_file_id, [])
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

    {inserted_count, _} =
      Repo.insert_all(TargetPopulation, inserts,
        on_conflict: :nothing,
        conflict_target: [:target_band_id, :me_file_id]
      )

    inserted_count
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

  defp broadcast_to_campaigns_using_target(target_id) do
    alias Qlarius.Sponster.Campaigns.Campaign
    require Logger

    campaigns =
      from(c in Campaign,
        where: c.target_id == ^target_id and is_nil(c.deactivated_at),
        select: {c.id, c.marketer_id}
      )
      |> Repo.all()

    Logger.info(
      "PopulateTargetWorker: Broadcasting target_populated to #{length(campaigns)} campaigns"
    )

    Enum.each(campaigns, fn {campaign_id, marketer_id} ->
      CampaignPubSub.broadcast_target_populated(campaign_id)
      CampaignPubSub.broadcast_marketer_campaign_updated(marketer_id, campaign_id)
    end)
  end

  defp populate_bands_bottom_up(sorted_bands) do
    require Logger

    {_final_candidates, populations} =
      Enum.reduce(sorted_bands, {nil, %{}}, fn band, {prev_candidates, populations_acc} ->
        trait_group_ids = Enum.map(band.trait_groups, & &1.id)

        candidates =
          if prev_candidates == nil do
            Logger.info(
              "PopulateTargetWorker: Finding me_files for outermost band #{band.id} with #{length(trait_group_ids)} trait_groups"
            )

            find_me_files_matching_all_trait_groups(trait_group_ids)
          else
            Logger.info(
              "PopulateTargetWorker: Filtering #{length(prev_candidates)} candidates for band #{band.id}"
            )

            filter_candidates_for_next_band(prev_candidates, trait_group_ids)
          end

        Logger.info(
          "PopulateTargetWorker: Band #{band.id} matched #{length(candidates)} me_files"
        )

        new_populations =
          Enum.reduce(candidates, populations_acc, fn me_file_id, acc ->
            Map.put(acc, me_file_id, band.id)
          end)

        {candidates, new_populations}
      end)

    populations
  end

  defp find_me_files_matching_all_trait_groups(trait_group_ids) do
    trait_ids_by_group =
      from(tgt in Qlarius.Sponster.Campaigns.TraitGroupTrait,
        where: tgt.trait_group_id in ^trait_group_ids,
        select: {tgt.trait_group_id, tgt.trait_id}
      )
      |> Repo.all()
      |> Enum.group_by(fn {tg_id, _trait_id} -> tg_id end, fn {_tg_id, trait_id} -> trait_id end)

    if map_size(trait_ids_by_group) != length(trait_group_ids) do
      require Logger

      Logger.warning(
        "PopulateTargetWorker: Some trait_groups have no traits, expected #{length(trait_group_ids)}, got #{map_size(trait_ids_by_group)}"
      )

      []
    else
      base_query = from(mft in MeFileTag, as: :base)

      query_with_conditions =
        Enum.reduce(trait_group_ids, base_query, fn tg_id, query ->
          trait_ids = Map.get(trait_ids_by_group, tg_id, [])

          where(
            query,
            [base: mft],
            exists(
              from(mft2 in MeFileTag,
                where:
                  mft2.me_file_id == parent_as(:base).me_file_id and mft2.trait_id in ^trait_ids
              )
            )
          )
        end)

      query_with_conditions
      |> select([base: mft], mft.me_file_id)
      |> distinct(true)
      |> Repo.all()
    end
  end

  defp filter_candidates_for_next_band(prev_candidates, new_trait_group_ids) do
    trait_ids_by_group =
      from(tgt in Qlarius.Sponster.Campaigns.TraitGroupTrait,
        where: tgt.trait_group_id in ^new_trait_group_ids,
        select: {tgt.trait_group_id, tgt.trait_id}
      )
      |> Repo.all()
      |> Enum.group_by(fn {tg_id, _trait_id} -> tg_id end, fn {_tg_id, trait_id} -> trait_id end)

    if map_size(trait_ids_by_group) != length(new_trait_group_ids) do
      require Logger

      Logger.warning(
        "PopulateTargetWorker: Some trait_groups have no traits in filter, expected #{length(new_trait_group_ids)}, got #{map_size(trait_ids_by_group)}"
      )

      []
    else
      base_query =
        from(mft in MeFileTag, as: :base)
        |> where([mft], mft.me_file_id in ^prev_candidates)

      query_with_conditions =
        Enum.reduce(new_trait_group_ids, base_query, fn tg_id, query ->
          trait_ids = Map.get(trait_ids_by_group, tg_id, [])

          where(
            query,
            [base: mft],
            exists(
              from(mft2 in MeFileTag,
                where:
                  mft2.me_file_id == parent_as(:base).me_file_id and mft2.trait_id in ^trait_ids
              )
            )
          )
        end)

      query_with_conditions
      |> select([base: mft], mft.me_file_id)
      |> distinct(true)
      |> Repo.all()
    end
  end

  defp calculate_population_changes(new_populations, existing_populations) do
    require Logger

    new_populations_set =
      new_populations
      |> Enum.map(fn {me_file_id, band_id} -> {me_file_id, band_id} end)
      |> MapSet.new()

    populations_to_insert =
      MapSet.difference(new_populations_set, existing_populations)
      |> MapSet.to_list()

    populations_to_delete =
      MapSet.difference(existing_populations, new_populations_set)
      |> MapSet.to_list()

    Logger.info(
      "PopulateTargetWorker: #{length(populations_to_insert)} to insert, #{length(populations_to_delete)} to delete"
    )

    {populations_to_insert, populations_to_delete}
  end
end
