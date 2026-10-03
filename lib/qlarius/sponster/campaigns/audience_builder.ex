defmodule Qlarius.Sponster.Campaigns.AudienceBuilder do
  @moduledoc """
  Shared rules for trait groups used by creator audiences and the admin
  campaign API.

  A group holds active children of one parent trait, or a free set of traits
  when it has no parent. Editing the traits of a group that sits on more than
  one target is refused here; the caller copies the target instead of changing
  a shared group underneath another audience.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{TargetBand, TargetBandTraitGroup, Targets, TraitGroupTrait}
  alias Qlarius.YouData.Traits.Trait

  def validate_traits(parent_trait_id, trait_ids) do
    trait_ids =
      trait_ids |> List.wrap() |> Enum.map(&id/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    cond do
      trait_ids == [] ->
        {:error, :traits_required}

      is_nil(parent_trait_id) ->
        {:ok, trait_ids}

      true ->
        parent_id = id(parent_trait_id)

        children =
          from(t in Trait,
            where: t.id in ^trait_ids and t.parent_trait_id == ^parent_id and t.is_active == true,
            select: t.id
          )
          |> Repo.all()

        missing = trait_ids -- children

        if missing == [] do
          {:ok, trait_ids}
        else
          {:error, {:traits_not_children, missing}}
        end
    end
  end

  def shared?(trait_group_id) do
    from(tbtg in TargetBandTraitGroup,
      join: tb in TargetBand,
      on: tb.id == tbtg.target_band_id,
      where: tbtg.trait_group_id == ^trait_group_id,
      select: tb.target_id,
      distinct: true
    )
    |> Repo.aggregate(:count) > 1
  end

  def frozen?(trait_group_id) do
    from(tbtg in TargetBandTraitGroup,
      join: tb in TargetBand,
      on: tb.id == tbtg.target_band_id,
      where: tbtg.trait_group_id == ^trait_group_id,
      select: tb.target_id,
      distinct: true
    )
    |> Repo.all()
    |> Enum.filter(&Targets.is_frozen?/1)
  end

  def replace_traits!(group, trait_ids) do
    from(tgt in TraitGroupTrait, where: tgt.trait_group_id == ^group.id)
    |> Repo.delete_all()

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      Enum.map(trait_ids, fn trait_id ->
        %{
          trait_group_id: group.id,
          trait_id: trait_id,
          created_at: now,
          updated_at: now
        }
      end)

    if rows != [], do: Repo.insert_all(TraitGroupTrait, rows)
    group
  end

  defp id(id) when is_integer(id), do: id

  defp id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp id(_), do: nil
end
