defmodule Qlarius.Jobs.SyncMeFileToTargetPopulationsWorker do
  use Oban.Worker,
    queue: :targets,
    max_attempts: 3,
    unique: [period: 120, keys: [:me_file_id], states: [:available, :scheduled]]

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, TargetPopulation}
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.Jobs.{ReconcileOffersForMeFileWorker, SnapshotBandPopulationsWorker}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"me_file_id" => me_file_id} = args}) do
    require Logger
    deleted_trait_ids = Map.get(args, "deleted_trait_ids", [])

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Processing me_file #{me_file_id}, deleted_traits=#{inspect(deleted_trait_ids)}"
    )

    active_campaigns = get_active_campaigns()

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Found #{length(active_campaigns)} active campaigns"
    )

    {new_populations, removed_populations} =
      sync_populations_for_me_file(me_file_id, active_campaigns)

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

  defp get_active_campaigns do
    from(c in Campaign,
      where: is_nil(c.deactivated_at),
      preload: [target: :target_bands]
    )
    |> Repo.all()
  end

  defp sync_populations_for_me_file(me_file_id, campaigns) do
    optimal_bands_by_target =
      Enum.reduce(campaigns, %{}, fn campaign, acc ->
        if campaign.target do
          optimal_band = find_optimal_band_for_me_file(campaign.target, me_file_id)

          if optimal_band do
            Map.put(acc, campaign.target.id, optimal_band.id)
          else
            acc
          end
        else
          acc
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
      insert_target_populations(me_file_id, bands_to_add)
      enqueue_snapshot_jobs(bands_to_add)
    end

    if bands_to_remove != [] do
      delete_target_populations(me_file_id, bands_to_remove)
    end

    {bands_to_add, bands_to_remove}
  end

  defp find_optimal_band_for_me_file(target, me_file_id) do
    target = Repo.preload(target, target_bands: [trait_groups: :traits])
    bands = target.target_bands

    sorted_bands = Enum.sort_by(bands, &length(&1.trait_groups), :desc)

    Enum.find(sorted_bands, fn band ->
      me_file_matches_band?(me_file_id, band)
    end)
  end

  defp me_file_matches_band?(me_file_id, band) do
    trait_groups = band.trait_groups

    if trait_groups == [] do
      false
    else
      Enum.all?(trait_groups, fn trait_group ->
        me_file_has_trait_from_group?(me_file_id, trait_group)
      end)
    end
  end

  defp me_file_has_trait_from_group?(me_file_id, trait_group) do
    trait_ids = Enum.map(trait_group.traits, & &1.id)

    if trait_ids == [] do
      false
    else
      exists =
        from(mft in MeFileTag,
          where: mft.me_file_id == ^me_file_id,
          where: mft.trait_id in ^trait_ids,
          select: count(mft.id)
        )
        |> Repo.one()

      exists > 0
    end
  end

  defp insert_target_populations(me_file_id, band_ids) do
    require Logger
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    inserts =
      Enum.map(band_ids, fn band_id ->
        %{
          me_file_id: me_file_id,
          target_band_id: band_id,
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
      "SyncMeFileToTargetPopulationsWorker: Inserted #{count} new populations for me_file #{me_file_id}"
    )
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

  defp enqueue_snapshot_jobs(band_ids) do
    require Logger

    Logger.info(
      "SyncMeFileToTargetPopulationsWorker: Enqueuing snapshot jobs for #{length(band_ids)} bands"
    )

    Enum.each(band_ids, fn band_id ->
      SnapshotBandPopulationsWorker.new(%{band_id: band_id})
      |> Oban.insert()
    end)
  end
end
