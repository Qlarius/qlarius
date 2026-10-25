defmodule Qlarius.Sponster.Campaigns.BandMatch do
  @moduledoc """
  The one definition of "this MeFile is in this band", shared by the batch
  populate worker, the per-MeFile sync worker, and dry-run reach counts so they
  always agree.

  A band matches a MeFile that holds a trait from every include group and holds
  no trait from any Anti-Trait Group. A band with no include groups, or an
  include group with no traits, matches nobody. An Anti-Trait Group with no
  traits removes nobody and is ignored.

  Groups are expected with `traits` preloaded.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{TraitGroup, TraitGroupTrait}
  alias Qlarius.YouData.MeFiles.MeFileTag

  def include_groups(groups), do: Enum.reject(groups, &TraitGroup.anti?/1)
  def anti_groups(groups), do: Enum.filter(groups, &TraitGroup.anti?/1)

  @doc """
  Trait id sets for a band's groups, split by role, with empty anti sets
  dropped. Returns `{include_sets, anti_sets}`.
  """
  def trait_id_sets(groups) do
    {
      groups |> include_groups() |> Enum.map(&trait_ids/1),
      groups |> anti_groups() |> Enum.map(&trait_ids/1) |> Enum.reject(&(&1 == []))
    }
  end

  defp trait_ids(%{traits: traits}) when is_list(traits),
    do: traits |> Enum.map(& &1.id) |> Enum.sort()

  @doc """
  Whether a band can match anyone at all.
  """
  def matchable?({include_sets, _anti_sets}) do
    include_sets != [] and not Enum.any?(include_sets, &(&1 == []))
  end

  @doc """
  MeFile ids matching the given sets, optionally restricted to `candidates`.
  """
  def me_file_ids({_include_sets, _anti_sets} = sets, candidates \\ nil) do
    if matchable?(sets) do
      sets
      |> query(candidates)
      |> select([base: mft], mft.me_file_id)
      |> distinct(true)
      |> Repo.all()
    else
      []
    end
  end

  @doc """
  Loads the trait id sets for groups given only by id, then matches. Groups are
  read from the database so a dry-run and a populate see the same membership.
  """
  def me_file_ids_for_group_ids([]), do: []

  def me_file_ids_for_group_ids(group_ids) do
    group_ids |> load_sets() |> me_file_ids()
  end

  def load_sets(group_ids) do
    roles =
      from(tg in TraitGroup, where: tg.id in ^group_ids, select: {tg.id, tg.role})
      |> Repo.all()
      |> Map.new()

    ids_by_group =
      from(tgt in TraitGroupTrait,
        where: tgt.trait_group_id in ^group_ids,
        select: {tgt.trait_group_id, tgt.trait_id}
      )
      |> Repo.all()
      |> Enum.group_by(fn {tg_id, _} -> tg_id end, fn {_, trait_id} -> trait_id end)

    groups =
      Enum.map(group_ids, fn id ->
        %{
          role: Map.get(roles, id, "include"),
          traits: Enum.map(Map.get(ids_by_group, id, []), &%{id: &1})
        }
      end)

    # A requested include group that no longer exists matches nobody.
    if Enum.any?(group_ids, &(not Map.has_key?(roles, &1))) do
      {[[]], []}
    else
      trait_id_sets(groups)
    end
  end

  @doc """
  Ecto query over `me_file_tags` (aliased `:base`) with one `exists` per
  include set and one `not exists` per anti set.
  """
  def query({include_sets, anti_sets}, candidates \\ nil) do
    base =
      case candidates do
        nil -> from(mft in MeFileTag, as: :base)
        ids -> from(mft in MeFileTag, as: :base, where: mft.me_file_id in ^ids)
      end

    base
    |> then(
      &Enum.reduce(include_sets, &1, fn ids, q ->
        where(q, [base: mft], exists(tag_subquery(ids)))
      end)
    )
    |> then(
      &Enum.reduce(anti_sets, &1, fn ids, q ->
        where(q, [base: mft], not exists(tag_subquery(ids)))
      end)
    )
  end

  defp tag_subquery(trait_ids) do
    from(mft2 in MeFileTag,
      where: mft2.me_file_id == parent_as(:base).me_file_id and mft2.trait_id in ^trait_ids
    )
  end

  @doc """
  Whether one MeFile is in a band, memoizing "holds a trait from this set" per
  trait id set in `cache`, since the same group recurs across bands and
  targets. The cache belongs to one MeFile; start a fresh one per MeFile.
  Anti-groups reuse the same cache entry inverted. Checking stops at the first
  failing include group or the first matching anti-group.

  Returns `{boolean, cache}`.
  """
  def matches?(me_file_id, groups, cache \\ %{}) do
    {include_sets, anti_sets} = sets = trait_id_sets(groups)

    if matchable?(sets) do
      with {true, cache} <- all?(include_sets, me_file_id, cache, true),
           {true, cache} <- all?(anti_sets, me_file_id, cache, false) do
        {true, cache}
      end
    else
      {false, cache}
    end
  end

  defp all?(sets, me_file_id, cache, wanted) do
    Enum.reduce_while(sets, {true, cache}, fn ids, {_so_far, cache} ->
      {holds?, cache} = holds_any?(me_file_id, ids, cache)
      if holds? == wanted, do: {:cont, {true, cache}}, else: {:halt, {false, cache}}
    end)
  end

  defp holds_any?(me_file_id, trait_ids, cache) do
    case Map.fetch(cache, trait_ids) do
      {:ok, holds?} ->
        {holds?, cache}

      :error ->
        holds? =
          from(mft in MeFileTag,
            where: mft.me_file_id == ^me_file_id and mft.trait_id in ^trait_ids
          )
          |> Repo.exists?()

        {holds?, Map.put(cache, trait_ids, holds?)}
    end
  end
end
