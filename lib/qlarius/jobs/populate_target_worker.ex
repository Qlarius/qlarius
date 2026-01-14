defmodule Qlarius.Jobs.PopulateTargetWorker do
  use Oban.Worker, queue: :targets, max_attempts: 3

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Target, TargetBand, TargetPopulation, Targets, CampaignPubSub}
  alias Qlarius.YouData.MeFiles.MeFileTag

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
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        inserts =
          Enum.map(populations_to_insert, fn {me_file_id, band_id} ->
            %{
              me_file_id: me_file_id,
              target_band_id: band_id,
              created_at: now,
              updated_at: now
            }
          end)

        {inserted_count, _} =
          Repo.insert_all(TargetPopulation, inserts,
            on_conflict: :nothing,
            conflict_target: [:target_band_id, :me_file_id]
          )

        Logger.info("PopulateTargetWorker: Inserted #{inserted_count} populations")
      end

      Targets.update_target(target, %{
        population_status: "populated",
        last_populated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })

      timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.to_string()
      Logger.info("PopulateTargetWorker: ✅ COMPLETE for target_id=#{target_id} at #{timestamp}")

      enqueue_snapshot_jobs(target_id, bands)

      Phoenix.PubSub.broadcast(
        Qlarius.PubSub,
        "targets",
        {:target_populated, target_id, timestamp}
      )

      broadcast_to_campaigns_using_target(target_id)

      :ok
    end
  end

  defp enqueue_snapshot_jobs(_target_id, bands) do
    require Logger
    Logger.info("PopulateTargetWorker: Enqueuing snapshot jobs for #{length(bands)} bands")

    Enum.each(bands, fn band ->
      Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: band.id})
      |> Oban.insert()
    end)
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
