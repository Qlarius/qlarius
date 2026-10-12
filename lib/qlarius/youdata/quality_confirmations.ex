defmodule Qlarius.YouData.QualityConfirmations do
  @moduledoc """
  A person's confirmation that a conflict pair or a wide tag count is accurate.

  The row holds until the next save of a parent it touches, or until it is
  older than that parent's stale_days. Loading a MeFile's quality deletes
  the expired rows. The integrity report only counts rows still inside the
  window and does not delete them.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.QualityConfirmation
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  def confirm(me_file_id, "conflict", relationship_id) do
    with id when is_integer(id) <- parse_id(relationship_id),
         %TraitRelationship{kind: "conflicts"} <- Repo.get(TraitRelationship, id) do
      upsert(%{
        me_file_id: me_file_id,
        kind: "conflict",
        trait_relationship_id: id,
        confirmed_at: now()
      })
    else
      _ -> :error
    end
  end

  def confirm(me_file_id, "count", trait_id) do
    with id when is_integer(id) <- parse_id(trait_id),
         %Trait{} <- Repo.get(Trait, id) do
      upsert(%{
        me_file_id: me_file_id,
        kind: "count",
        trait_id: id,
        confirmed_at: now()
      })
    else
      _ -> :error
    end
  end

  def confirm(_me_file_id, _kind, _id), do: :error

  # One tap can cover every relationship shown on a single conflicting tag.
  def confirm_ids(me_file_id, kind, ids) when is_binary(ids) do
    apply_ids(me_file_id, kind, ids, &confirm/3)
  end

  def withdraw(me_file_id, "conflict", relationship_id) do
    with id when is_integer(id) <- parse_id(relationship_id) do
      Repo.delete_all(
        from c in QualityConfirmation,
          where:
            c.me_file_id == ^me_file_id and c.kind == "conflict" and
              c.trait_relationship_id == ^id
      )

      :ok
    else
      _ -> :error
    end
  end

  def withdraw(me_file_id, "count", trait_id) do
    with id when is_integer(id) <- parse_id(trait_id) do
      Repo.delete_all(
        from c in QualityConfirmation,
          where: c.me_file_id == ^me_file_id and c.kind == "count" and c.trait_id == ^id
      )

      :ok
    else
      _ -> :error
    end
  end

  def withdraw(_me_file_id, _kind, _id), do: :error

  def withdraw_ids(me_file_id, kind, ids) when is_binary(ids) do
    apply_ids(me_file_id, kind, ids, &withdraw/3)
  end

  defp apply_ids(me_file_id, kind, ids, fun) do
    results =
      ids
      |> String.split(",", trim: true)
      |> Enum.map(&fun.(me_file_id, kind, &1))

    if :ok in results, do: :ok, else: :error
  end

  @doc """
  Drops expired confirmations for this MeFile and returns the ones that still hold.
  """
  def prepare(me_file_id, now \\ DateTime.utc_now()) do
    rows = Repo.all(from c in QualityConfirmation, where: c.me_file_id == ^me_file_id)
    {live, expired} = partition(rows, now)
    delete_ids(expired)

    %{
      conflicts:
        Map.new(for row <- live, row.kind == "conflict", do: {row.trait_relationship_id, row.confirmed_at}),
      counts: Map.new(for row <- live, row.kind == "count", do: {row.trait_id, row.confirmed_at})
    }
  end

  @doc """
  Live confirmations grouped for the integrity report. Does not delete expired rows.
  """
  def report(now \\ DateTime.utc_now()) do
    rows =
      QualityConfirmation
      |> preload(trait_relationship: [:trait, :related_trait])
      |> Repo.all()

    {live, _expired} = partition(rows, now)

    conflicts =
      live
      |> Enum.filter(&(&1.kind == "conflict"))
      |> Enum.group_by(& &1.trait_relationship_id)
      |> Enum.map(fn {_id, [first | _] = group} ->
        relationship = first.trait_relationship

        %{
          kind: "conflict",
          relationship_id: relationship.id,
          trait_id: relationship.trait_id,
          related_trait_id: relationship.related_trait_id,
          severity: relationship.severity,
          count: length(group)
        }
      end)

    counts =
      live
      |> Enum.filter(&(&1.kind == "count"))
      |> Enum.group_by(& &1.trait_id)
      |> Enum.map(fn {trait_id, group} ->
        %{kind: "count", trait_id: trait_id, count: length(group)}
      end)

    Enum.sort_by(conflicts ++ counts, & &1.count, :desc)
  end

  def clear_for_parent(me_file_id, parent_trait_id) do
    parent_trait_id = parse_id(parent_trait_id)
    child_ids = from(t in Trait, where: t.parent_trait_id == ^parent_trait_id, select: t.id)

    relationship_ids =
      from r in TraitRelationship,
        where:
          r.kind == "conflicts" and
            (r.trait_id == ^parent_trait_id or r.related_trait_id == ^parent_trait_id or
               r.trait_id in subquery(child_ids) or r.related_trait_id in subquery(child_ids)),
        select: r.id

    Repo.delete_all(
      from c in QualityConfirmation,
        where:
          c.me_file_id == ^me_file_id and c.kind == "count" and c.trait_id == ^parent_trait_id
    )

    Repo.delete_all(
      from c in QualityConfirmation,
        where:
          c.me_file_id == ^me_file_id and c.kind == "conflict" and
            c.trait_relationship_id in subquery(relationship_ids)
    )

    :ok
  end

  defp upsert(%{kind: "conflict"} = attrs) do
    upsert_where(
      [
        me_file_id: attrs.me_file_id,
        kind: "conflict",
        trait_relationship_id: attrs.trait_relationship_id
      ],
      attrs
    )
  end

  defp upsert(%{kind: "count"} = attrs) do
    upsert_where(
      [me_file_id: attrs.me_file_id, kind: "count", trait_id: attrs.trait_id],
      attrs
    )
  end

  defp upsert_where(where, attrs) do
    case Repo.get_by(QualityConfirmation, where) do
      nil ->
        %QualityConfirmation{}
        |> QualityConfirmation.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end

      confirmation ->
        confirmation
        |> Ecto.Changeset.change(confirmed_at: attrs.confirmed_at)
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
    end
  end

  defp partition(rows, now) do
    windows = windows(rows)

    Enum.split_with(rows, fn row ->
      case Map.get(windows, row.id) do
        nil -> true
        days -> DateTime.diff(now, row.confirmed_at, :day) <= days
      end
    end)
  end

  defp windows(rows) do
    relationship_ids =
      rows |> Enum.map(& &1.trait_relationship_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    relationships =
      if relationship_ids == [] do
        %{}
      else
        TraitRelationship
        |> where([r], r.id in ^relationship_ids)
        |> Repo.all()
        |> Map.new(&{&1.id, &1})
      end

    trait_ids =
      rows
      |> Enum.flat_map(fn row ->
        case Map.get(relationships, row.trait_relationship_id) do
          nil -> [row.trait_id]
          relationship -> [row.trait_id, relationship.trait_id, relationship.related_trait_id]
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    traits = trait_rows(trait_ids)

    parent_ids =
      traits
      |> Map.values()
      |> Enum.map(& &1.parent_trait_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    parent_stale =
      if parent_ids == [] do
        %{}
      else
        Repo.all(from t in Trait, where: t.id in ^parent_ids, select: {t.id, t.stale_days})
        |> Map.new()
      end

    Map.new(rows, fn row ->
      {row.id, window(row, relationships, traits, parent_stale)}
    end)
  end

  defp trait_rows([]), do: %{}

  defp trait_rows(ids) do
    Repo.all(
      from t in Trait,
        where: t.id in ^ids,
        select: %{id: t.id, parent_trait_id: t.parent_trait_id, stale_days: t.stale_days}
    )
    |> Map.new(&{&1.id, &1})
  end

  defp window(%{kind: "count", trait_id: trait_id}, _relationships, traits, parent_stale) do
    side_stale(trait_id, traits, parent_stale)
  end

  defp window(%{kind: "conflict"} = row, relationships, traits, parent_stale) do
    case Map.get(relationships, row.trait_relationship_id) do
      nil ->
        nil

      relationship ->
        [relationship.trait_id, relationship.related_trait_id]
        |> Enum.map(&side_stale(&1, traits, parent_stale))
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> nil
          days -> Enum.min(days)
        end
    end
  end

  defp window(_row, _relationships, _traits, _parent_stale), do: nil

  defp side_stale(nil, _traits, _parent_stale), do: nil

  defp side_stale(trait_id, traits, parent_stale) do
    case Map.get(traits, trait_id) do
      nil ->
        nil

      %{parent_trait_id: nil, stale_days: days} ->
        days

      %{parent_trait_id: parent_id} ->
        Map.get(parent_stale, parent_id)
    end
  end

  defp delete_ids([]), do: :ok

  defp delete_ids(rows) do
    ids = Enum.map(rows, & &1.id)
    Repo.delete_all(from c in QualityConfirmation, where: c.id in ^ids)
    :ok
  end

  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_id(_), do: nil

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
