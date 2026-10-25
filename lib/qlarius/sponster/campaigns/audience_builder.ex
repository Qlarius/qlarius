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

  alias Qlarius.Sponster.Campaigns.{
    TargetBand,
    TargetBandTraitGroup,
    Targets,
    TraitGroup,
    TraitGroupTrait
  }

  alias Qlarius.YouData.Traits.Trait

  @doc """
  A group's traits split by topic: one entry per parent trait, each with the
  parent and the answers held under it, ordered by the parent's display order.
  Expects `traits: :parent_trait` preloaded.
  """
  def topics(%TraitGroup{traits: traits}) when is_list(traits) do
    traits
    |> Enum.group_by(& &1.parent_trait_id)
    |> Enum.map(fn {_parent_id, [first | _] = children} ->
      %{
        parent: first.parent_trait,
        traits: Enum.sort_by(children, &{&1.display_order, &1.trait_name})
      }
    end)
    |> Enum.sort_by(fn %{parent: parent} ->
      {(parent && parent.display_order) || 0, (parent && parent.trait_name) || ""}
    end)
  end

  @doc """
  The parent id a group carries: the one parent every trait shares, or nil when
  the group spans topics. Multi-topic groups are stored with a nil parent, and
  `validate_traits/2` skips the parentage check for them.
  """
  def derived_parent_id(trait_ids) when is_list(trait_ids) do
    case trait_ids |> Enum.map(&id/1) |> Enum.reject(&is_nil/1) do
      [] ->
        nil

      ids ->
        from(t in Trait, where: t.id in ^ids, select: t.parent_trait_id, distinct: true)
        |> Repo.all()
        |> case do
          [single] -> single
          _ -> nil
        end
    end
  end

  @doc """
  Replaces the answers a group holds under one topic, leaving other topics as
  they are. A topic the group did not hold is added. Refused on a group that
  sits under a frozen target or on more than one target, same as the admin API.

  Options: `:title` and `:description` update the group's own fields.
  """
  def set_topic(%TraitGroup{} = group, parent_trait_id, trait_ids, opts \\ []) do
    parent_id = id(parent_trait_id)
    group = Repo.preload(group, :traits, force: true)

    kept = group.traits |> Enum.reject(&(&1.parent_trait_id == parent_id)) |> Enum.map(& &1.id)

    with :ok <- editable(group),
         {:ok, new_ids} <- validate_traits(parent_id, trait_ids) do
      write_traits(group, kept ++ new_ids, opts)
    end
  end

  @doc """
  Drops one topic from a group. A group must keep at least one topic; delete
  the group instead of emptying it.
  """
  def remove_topic(%TraitGroup{} = group, parent_trait_id) do
    parent_id = id(parent_trait_id)
    group = Repo.preload(group, :traits, force: true)

    kept = group.traits |> Enum.reject(&(&1.parent_trait_id == parent_id)) |> Enum.map(& &1.id)

    cond do
      kept == [] -> {:error, :last_topic}
      length(kept) == length(group.traits) -> {:error, :topic_not_in_group}
      true -> with :ok <- editable(group), do: write_traits(group, kept, [])
    end
  end

  defp editable(group) do
    cond do
      (frozen_ids = frozen?(group.id)) != [] -> {:error, {:frozen_target, frozen_ids}}
      shared?(group.id) -> {:error, :trait_group_shared}
      true -> :ok
    end
  end

  defp write_traits(group, trait_ids, opts) do
    attrs =
      %{parent_trait_id: derived_parent_id(trait_ids)}
      |> put_present(:title, opts[:title])
      |> put_present(:description, opts[:description])

    Repo.transaction(fn ->
      case group |> TraitGroup.changeset(attrs) |> Repo.update() do
        {:ok, group} ->
          group
          |> replace_traits!(trait_ids)
          |> Repo.preload([traits: :parent_trait], force: true)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp put_present(attrs, _key, nil), do: attrs

  defp put_present(attrs, key, value) when is_binary(value) do
    case String.trim(value) do
      "" -> attrs
      trimmed -> Map.put(attrs, key, trimmed)
    end
  end

  def validate_traits(parent_trait_id, trait_ids) do
    trait_ids =
      trait_ids |> List.wrap() |> Enum.map(&id/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    cond do
      trait_ids == [] ->
        {:error, :traits_required}

      is_nil(parent_trait_id) ->
        found =
          from(t in Trait,
            where: t.id in ^trait_ids and not is_nil(t.parent_trait_id) and t.is_active == true,
            select: t.id
          )
          |> Repo.all()

        case trait_ids -- found do
          [] -> {:ok, trait_ids}
          missing -> {:error, {:traits_not_found, missing}}
        end

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

    if rows != [] do
      rows
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn chunk ->
        Repo.insert_all(TraitGroupTrait, chunk)
      end)
    end

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
