defmodule Qlarius.Sponster.Campaigns.Targets do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Target, TargetBand, TargetBandTraitGroup, TraitGroup}

  def list_targets_for_marketer(marketer_id) do
    from(t in Target,
      where: t.marketer_id == ^marketer_id,
      order_by: [desc: t.created_at],
      preload: [target_bands: [:trait_groups]]
    )
    |> Repo.all()
    |> Enum.map(&add_target_stats/1)
  end

  def get_target_for_marketer!(id, marketer_id) do
    from(t in Target,
      where: t.id == ^id and t.marketer_id == ^marketer_id,
      preload: [target_bands: [trait_groups: [], target_band_trait_groups: []]]
    )
    |> Repo.one!()
    |> add_target_stats()
  end

  def create_target(attrs) do
    %Target{}
    |> Target.changeset(attrs)
    |> Repo.insert()
  end

  def update_target(%Target{} = target, attrs) do
    target
    |> Target.changeset(attrs)
    |> Repo.update()
  end

  def delete_target(%Target{} = target) do
    Repo.delete(target)
  end

  def create_bullseye_band(target_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put("target_id", target_id)
      |> Map.put("is_bullseye", "1")

    %TargetBand{}
    |> TargetBand.changeset(attrs)
    |> Repo.insert()
  end

  def get_bullseye_for_target(target_id) do
    from(tb in TargetBand,
      where: tb.target_id == ^target_id and tb.is_bullseye == "1",
      preload: [:trait_groups]
    )
    |> Repo.one()
  end

  def get_target_band!(id) do
    from(tb in TargetBand,
      where: tb.id == ^id,
      preload: [:trait_groups, :target]
    )
    |> Repo.one!()
  end

  def add_trait_group_to_band(band_id, trait_group_id) do
    existing =
      from(tbtg in TargetBandTraitGroup,
        join: tb in TargetBand,
        on: tbtg.target_band_id == tb.id,
        where: tb.target_id == ^get_target_id_for_band(band_id),
        where: tbtg.trait_group_id == ^trait_group_id
      )
      |> Repo.one()

    if existing do
      {:error, :trait_group_already_in_target}
    else
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      %TargetBandTraitGroup{}
      |> TargetBandTraitGroup.changeset(%{
        target_band_id: band_id,
        trait_group_id: trait_group_id
      })
      |> Ecto.Changeset.put_change(:created_at, now)
      |> Ecto.Changeset.put_change(:updated_at, now)
      |> Repo.insert()
    end
  end

  def remove_trait_group_from_band(band_id, trait_group_id) do
    from(tbtg in TargetBandTraitGroup,
      where: tbtg.target_band_id == ^band_id and tbtg.trait_group_id == ^trait_group_id
    )
    |> Repo.delete_all()

    {:ok, :removed}
  end

  def create_outer_band(target_id, excluded_trait_group_id) do
    outermost_band = get_outermost_band(target_id)

    if !outermost_band do
      {:error, :no_bands_exist}
    else
      trait_group_ids =
        outermost_band.trait_groups
        |> Enum.map(& &1.id)
        |> Enum.reject(&(&1 == excluded_trait_group_id))

      if trait_group_ids == [] do
        {:error, :cannot_create_empty_band}
      else
        {:ok, new_band} =
          %TargetBand{}
          |> TargetBand.changeset(%{
            target_id: target_id,
            is_bullseye: "0",
            user_created_by: outermost_band.user_created_by
          })
          |> Repo.insert()

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        associations =
          Enum.map(trait_group_ids, fn tg_id ->
            %{
              target_band_id: new_band.id,
              trait_group_id: tg_id,
              created_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(TargetBandTraitGroup, associations)

        {:ok, new_band}
      end
    end
  end

  def delete_outermost_band(target_id) do
    outermost_band = get_outermost_band(target_id)

    if !outermost_band do
      {:error, :no_bands_to_delete}
    else
      if outermost_band.is_bullseye == "1" do
        {:error, :cannot_delete_bullseye}
      else
        Repo.delete(outermost_band)
      end
    end
  end

  def get_bands_for_target(target_id) do
    from(tb in TargetBand,
      where: tb.target_id == ^target_id,
      preload: [trait_groups: [:traits]]
    )
    |> Repo.all()
    |> sort_bands_by_trait_count()
  end

  def get_outermost_band(target_id) do
    bands = get_bands_for_target(target_id)

    bands
    |> Enum.min_by(&length(&1.trait_groups), fn -> nil end)
  end

  def get_available_trait_groups_for_target(target_id, marketer_id) do
    used_trait_group_ids =
      from(tbtg in TargetBandTraitGroup,
        join: tb in TargetBand,
        on: tbtg.target_band_id == tb.id,
        where: tb.target_id == ^target_id,
        select: tbtg.trait_group_id
      )
      |> Repo.all()

    from(tg in TraitGroup,
      where: tg.marketer_id == ^marketer_id,
      where: is_nil(tg.deactivated_at),
      where: tg.id not in ^used_trait_group_ids,
      order_by: [asc: tg.title],
      preload: [:traits]
    )
    |> Repo.all()
  end

  def trigger_population(%Target{} = target) do
    {:ok, _target} = update_target(target, %{population_status: "populating"})

    {:ok, _job} =
      %{target_id: target.id}
      |> Qlarius.Jobs.PopulateTargetWorker.new(queue: :targets)
      |> Oban.insert()

    :ok
  end

  defp add_target_stats(target) do
    bullseye = get_bullseye_for_target(target.id)

    bullseye_trait_groups =
      case bullseye do
        nil -> []
        bullseye -> bullseye.trait_groups
      end

    bullseye_count = length(bullseye_trait_groups)
    outer_band_count = length(target.target_bands) - if(bullseye_count > 0, do: 1, else: 0)

    total_population =
      from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
        join: tb in TargetBand,
        on: tp.target_band_id == tb.id,
        where: tb.target_id == ^target.id,
        select: count(tp.id, :distinct)
      )
      |> Repo.one()

    is_frozen = is_frozen?(target.id)

    Map.merge(target, %{
      bullseye_trait_groups: bullseye_trait_groups,
      bullseye_trait_group_count: bullseye_count,
      outer_band_count: outer_band_count,
      total_population: total_population || 0,
      is_frozen: is_frozen
    })
  end

  defp get_target_id_for_band(band_id) do
    from(tb in TargetBand,
      where: tb.id == ^band_id,
      select: tb.target_id
    )
    |> Repo.one!()
  end

  defp sort_bands_by_trait_count(bands) do
    Enum.sort_by(bands, &length(&1.trait_groups), :desc)
  end

  def band_label(band, all_bands) do
    sorted_bands = sort_bands_by_trait_count(all_bands)

    if band.is_bullseye == "1" do
      "Bullseye"
    else
      index = Enum.find_index(sorted_bands, &(&1.id == band.id))

      if index do
        "Ring #{index}"
      else
        "Unknown"
      end
    end
  end

  def is_frozen?(target_id) do
    from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id,
      limit: 1
    )
    |> Repo.exists?()
  end

  def depopulate_target(target_id) do
    from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id
    )
    |> Repo.delete_all()

    target = Repo.get!(Target, target_id)

    update_target(target, %{
      population_status: "not_populated",
      last_populated_at: nil
    })
  end

  def get_band_population_counts(target_id) do
    from(tp in Qlarius.Sponster.Campaigns.TargetPopulation,
      join: tb in TargetBand,
      on: tp.target_band_id == tb.id,
      where: tb.target_id == ^target_id,
      group_by: tb.id,
      select: {tb.id, count(tp.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Converts matching_tags_snapshot from list format to tuple format for display.

  The snapshot is stored as nested lists in JSONB, but display functions like
  `trait_card` expect tuples. This converts:

  `[[parent_id, name, order, [[child_id, value, order]]]]`

  to:

  `[{parent_id, name, order, [{child_id, value, order}]}]`

  Handles various snapshot formats including:
  - `%{matching_tags_snapshot: %{"tags" => [...]}}`
  - `%{"tags" => [...]}`
  - Old format maps (returns empty list)
  """
  def snapshot_to_tuples(%{matching_tags_snapshot: %{"tags" => tags}})
      when is_list(tags) do
    convert_tags_to_tuples(tags)
  end

  def snapshot_to_tuples(%{"tags" => tags}) when is_list(tags) do
    convert_tags_to_tuples(tags)
  end

  def snapshot_to_tuples(%{"parent_trait_id" => _, "trait_id" => _, "trait_name" => _}) do
    []
  end

  def snapshot_to_tuples(_), do: []

  defp convert_tags_to_tuples(tags) do
    Enum.map(tags, fn
      [parent_id, name, order, children] when is_list(children) ->
        {parent_id, name, order, Enum.map(children, &List.to_tuple/1)}

      %{"parent_trait_id" => _, "trait_id" => _, "trait_name" => _} ->
        nil

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
