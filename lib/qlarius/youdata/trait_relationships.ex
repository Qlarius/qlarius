defmodule Qlarius.YouData.TraitRelationships do
  @moduledoc """
  Links between traits that should not be true together, or that usually
  come as a pair. A parent id means any value of that parent.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.YouData.TraitAudit
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitRelationship

  @max_bulk 1000

  def get(id) do
    Repo.get(TraitRelationship, id)
  end

  def create(attrs) do
    changeset = TraitRelationship.changeset(%TraitRelationship{}, attrs)

    # :nothing keeps a duplicate from aborting the surrounding transaction,
    # so a bulk call can report "exists" and continue.
    inserted =
      Repo.insert(changeset,
        on_conflict: :nothing,
        conflict_target: [:trait_id, :related_trait_id, :kind]
      )

    case inserted do
      {:ok, %{id: nil}} ->
        {:error, Ecto.Changeset.add_error(changeset, :trait_id, "already exists")}

      {:ok, relationship} ->
        TraitAudit.record_relationship("relationship_created", nil, relationship)
        {:ok, relationship}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(%TraitRelationship{} = relationship, attrs) do
    before = TraitAudit.snapshot(relationship)

    case relationship
         |> TraitRelationship.changeset(attrs)
         |> Repo.update() do
      {:ok, relationship} = ok ->
        TraitAudit.record_relationship("relationship_updated", before, relationship)
        ok

      error ->
        error
    end
  end

  def delete(%TraitRelationship{} = relationship) do
    TraitAudit.record_relationship_deleted(relationship)
    Repo.delete(relationship)
  end

  def list_for_parent(parent_id, kind \\ nil) do
    ids = family_ids(parent_id)

    TraitRelationship
    |> where([r], r.trait_id in ^ids or r.related_trait_id in ^ids)
    |> kind_filter(kind)
    |> order_by([r], asc: r.id)
    |> preload([:trait, :related_trait])
    |> Repo.all()
  end

  def search(query) when is_binary(query) do
    term = String.trim(query)

    if String.length(term) < 2 do
      []
    else
      like = "%#{term}%"

      Repo.all(
        from t in Trait,
          where: ilike(t.trait_name, ^like) and t.is_active == true,
          order_by: [asc: t.trait_name],
          limit: 8,
          select: %{id: t.id, trait_name: t.trait_name, parent_trait_id: t.parent_trait_id}
      )
    end
  end

  def warnings(%TraitRelationship{} = relationship) do
    relationship = Repo.preload(relationship, [:trait, :related_trait])
    left = relationship.trait
    right = relationship.related_trait
    parents = parent_map([left, right])

    []
    |> inactive_or_skip(left)
    |> inactive_or_skip(right)
    |> self_family(relationship, left, right, parents)
    |> both_kinds(relationship, left, right)
  end

  defp parent_map(traits) do
    ids = traits |> Enum.map(& &1.parent_trait_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if ids == [] do
      %{}
    else
      Repo.all(from t in Trait, where: t.id in ^ids)
      |> Map.new(&{&1.id, &1})
    end
  end

  defp inactive_or_skip(warnings, %Trait{is_active: false} = trait) do
    ["#{trait.trait_name} is inactive" | warnings]
  end

  defp inactive_or_skip(warnings, %Trait{is_skipped_tag: true} = trait) do
    ["#{trait.trait_name} is a skip answer" | warnings]
  end

  defp inactive_or_skip(warnings, _), do: warnings

  defp self_family(warnings, %{kind: "conflicts"}, left, right, parents) do
    cond do
      left.parent_trait_id == right.id or right.parent_trait_id == left.id ->
        ["a child conflicts with its own parent" | warnings]

      siblings_on_single_select?(left, right, parents) ->
        ["a child conflicts with a sibling under a single_select parent" | warnings]

      true ->
        warnings
    end
  end

  defp self_family(warnings, _, _, _, _), do: warnings

  defp siblings_on_single_select?(left, right, parents) do
    parent_id = left.parent_trait_id

    parent_id && parent_id == right.parent_trait_id &&
      case Map.get(parents, parent_id) do
        %{input_type: type} when type in ["single_select", "single_select_zip"] -> true
        _ -> false
      end
  end

  defp both_kinds(warnings, relationship, left, right) do
    other = if relationship.kind == "conflicts", do: "requires", else: "conflicts"

    exists? =
      Repo.exists?(
        from r in TraitRelationship,
          where:
            r.kind == ^other and
              ((r.trait_id == ^left.id and r.related_trait_id == ^right.id) or
                 (r.trait_id == ^right.id and r.related_trait_id == ^left.id))
      )

    if exists?, do: ["this pair has both conflicts and requires" | warnings], else: warnings
  end

  def list_among_children(parent_id, kind \\ nil) do
    ids = child_ids(parent_id)

    TraitRelationship
    |> where([r], r.trait_id in ^ids and r.related_trait_id in ^ids)
    |> kind_filter(kind)
    |> order_by([r], asc: r.id)
    |> preload([:trait, :related_trait])
    |> Repo.all()
  end

  def exclusive_child_ids(parent_id, opts \\ []) do
    except = MapSet.new(Keyword.get(opts, :except, []))

    ids =
      parent_id
      |> active_child_ids()
      |> Enum.reject(&MapSet.member?(except, &1))

    exclusive_among(ids)
  end

  def exclusive_ids_by_parent([]), do: %{}

  def exclusive_ids_by_parent(parent_ids) do
    children =
      Repo.all(
        from t in Trait,
          where: t.parent_trait_id in ^parent_ids and t.is_active == true,
          select: {t.parent_trait_id, t.id}
      )

    grouped = Enum.group_by(children, &elem(&1, 0), &elem(&1, 1))
    all_ids = Enum.map(children, &elem(&1, 1))

    pairs =
      if all_ids == [] do
        MapSet.new()
      else
        Repo.all(
          from r in TraitRelationship,
            where:
              r.kind == "conflicts" and r.trait_id in ^all_ids and
                r.related_trait_id in ^all_ids,
            select: {r.trait_id, r.related_trait_id}
        )
        |> MapSet.new()
      end

    Map.new(parent_ids, fn parent_id ->
      {parent_id, exclusive_among(Map.get(grouped, parent_id, []), pairs)}
    end)
  end

  def make_exclusive(parent_id, child_id, opts \\ []) do
    with {:ok, child} <- fetch_child(parent_id, child_id) do
      siblings = sibling_ids(parent_id, child.id, Keyword.get(opts, :include_inactive, false))

      Repo.transaction(fn ->
        rows = Enum.map(siblings, &link_conflict(child.id, &1, opts))

        if Enum.any?(rows, &(&1.status == "error")) do
          Repo.rollback(:invalid)
        else
          summarize_links(rows)
        end
      end)
    end
  end

  def unmake_exclusive(parent_id, child_id) do
    with {:ok, child} <- fetch_child(parent_id, child_id) do
      ids = child_ids(parent_id)

      links =
        Repo.all(
          from r in TraitRelationship,
            where:
              r.kind == "conflicts" and
                ((r.trait_id == ^child.id and r.related_trait_id in ^ids) or
                   (r.related_trait_id == ^child.id and r.trait_id in ^ids))
        )

      Repo.transaction(fn ->
        Enum.each(links, &delete/1)
        %{deleted: length(links), relationship_ids: Enum.map(links, & &1.id)}
      end)
    end
  end

  def extend_exclusive_conflicts(parent_id, new_ids, opts \\ []) do
    new_ids = new_ids |> Enum.map(&int/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if new_ids == [] do
      []
    else
      parent_id
      |> exclusive_child_ids(except: new_ids)
      |> Enum.flat_map(fn exclusive_id ->
        Enum.flat_map(new_ids, fn new_id ->
          case link_conflict(exclusive_id, new_id, opts) do
            %{status: "created", relationship: relationship} -> [relationship]
            _ -> []
          end
        end)
      end)
    end
  end

  def bulk(params) when is_map(params) do
    creates = if is_list(params["create"]), do: params["create"], else: []
    deletes = if is_list(params["delete"]), do: params["delete"], else: []

    cond do
      Map.has_key?(params, "create") and not is_list(params["create"]) ->
        {:error, :invalid_payload}

      Map.has_key?(params, "delete") and not is_list(params["delete"]) ->
        {:error, :invalid_payload}

      length(creates) + length(deletes) > @max_bulk ->
        {:error, :too_many_operations}

      true ->
        transact(params, fn ->
          Enum.map(deletes, &delete_item/1) ++ Enum.map(creates, &create_item/1)
        end)
    end
  end

  def to_json(%TraitRelationship{} = relationship) do
    relationship = Repo.preload(relationship, [:trait, :related_trait])

    %{
      id: relationship.id,
      trait_id: relationship.trait_id,
      trait_name: relationship.trait.trait_name,
      related_trait_id: relationship.related_trait_id,
      related_trait_name: relationship.related_trait.trait_name,
      kind: relationship.kind,
      note: relationship.note
    }
  end

  defp transact(params, fun) do
    dry = params["dry_run"] in [true, "true", "1", 1]

    case Repo.transaction(fn ->
           results = fun.()

           if dry or Enum.any?(results, &(&1.status == "error")) do
             Repo.rollback({:results, results})
           else
             results
           end
         end) do
      {:ok, results} ->
        {:ok, %{results: results, dry_run: false, rolled_back: false}}

      {:error, {:results, results}} ->
        body = %{results: results, dry_run: dry, rolled_back: true}
        if dry, do: {:ok, body}, else: {:error, body}
    end
  end

  defp create_item(item) when is_map(item) do
    attrs = %{
      "trait_id" => int(item["trait_id"]),
      "related_trait_id" => int(item["related_trait_id"]),
      "kind" => item["type"] || item["kind"],
      "note" => item["note"]
    }

    case create(attrs) do
      {:ok, relationship} ->
        result_row("created", relationship)

      {:error, %Ecto.Changeset{} = changeset} ->
        if already_exists?(changeset) do
          case find_pair(attrs["trait_id"], attrs["related_trait_id"], attrs["kind"]) do
            %TraitRelationship{} = relationship -> result_row("exists", relationship)
            _ -> error_row(changeset)
          end
        else
          error_row(changeset)
        end
    end
  end

  defp create_item(_), do: %{status: "error", errors: %{"item" => ["must be an object"]}}

  defp delete_item(id) when is_integer(id), do: delete_by_id(id)

  defp delete_item(id) when is_binary(id) do
    case int(id) do
      nil -> %{status: "error", errors: %{"id" => ["is invalid"]}}
      parsed -> delete_by_id(parsed)
    end
  end

  defp delete_item(item) when is_map(item) do
    cond do
      id = int(item["id"]) ->
        delete_by_id(id)

      item["trait_id"] && item["related_trait_id"] ->
        kind = item["type"] || item["kind"] || "conflicts"

        case find_pair(int(item["trait_id"]), int(item["related_trait_id"]), kind) do
          %TraitRelationship{} = relationship ->
            {:ok, _} = delete(relationship)
            %{status: "deleted", relationship_id: relationship.id}

          _ ->
            %{status: "not_found"}
        end

      true ->
        %{status: "error", errors: %{"id" => ["is required"]}}
    end
  end

  defp delete_item(_), do: %{status: "error", errors: %{"item" => ["must be an id or an object"]}}

  defp delete_by_id(id) do
    case get(id) do
      nil ->
        %{status: "not_found", relationship_id: id}

      relationship ->
        {:ok, _} = delete(relationship)
        %{status: "deleted", relationship_id: id}
    end
  end

  defp link_conflict(left_id, right_id, opts) do
    attrs = %{"trait_id" => left_id, "related_trait_id" => right_id, "kind" => "conflicts"}
    attrs = if opts[:note] in [nil, ""], do: attrs, else: Map.put(attrs, "note", opts[:note])

    case create(attrs) do
      {:ok, relationship} ->
        %{status: "created", relationship_id: relationship.id, relationship: relationship}

      {:error, %Ecto.Changeset{} = changeset} ->
        if already_exists?(changeset) do
          relationship = find_pair(left_id, right_id, "conflicts")

          %{
            status: "skipped",
            relationship_id: relationship && relationship.id,
            relationship: relationship
          }
        else
          %{status: "error", errors: error_messages(changeset)}
        end
    end
  end

  defp summarize_links(rows) do
    %{
      created: Enum.count(rows, &(&1.status == "created")),
      skipped: Enum.count(rows, &(&1.status == "skipped")),
      relationship_ids: rows |> Enum.map(& &1.relationship_id) |> Enum.reject(&is_nil/1)
    }
  end

  defp result_row(status, relationship) do
    %{
      status: status,
      relationship: to_json(relationship),
      warnings: warnings(relationship)
    }
  end

  defp error_row(changeset), do: %{status: "error", errors: error_messages(changeset)}

  defp already_exists?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {message, _}} -> message == "already exists" end)
  end

  defp error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp find_pair(left, right, kind)
       when is_integer(left) and is_integer(right) and is_binary(kind) do
    {trait_id, related_id} =
      if kind == "conflicts" and left > right, do: {right, left}, else: {left, right}

    Repo.get_by(TraitRelationship, trait_id: trait_id, related_trait_id: related_id, kind: kind)
  end

  defp find_pair(_, _, _), do: nil

  defp fetch_child(parent_id, child_id) do
    parent_id = int(parent_id)
    child_id = int(child_id)

    case Repo.get(Trait, child_id) do
      %Trait{parent_trait_id: ^parent_id} = child -> {:ok, child}
      %Trait{} -> {:error, :child_not_in_parent}
      nil -> {:error, :not_found}
    end
  end

  defp sibling_ids(parent_id, child_id, include_inactive) do
    query =
      from t in Trait,
        where: t.parent_trait_id == ^int(parent_id) and t.id != ^child_id,
        select: t.id

    query = if include_inactive, do: query, else: where(query, [t], t.is_active == true)
    Repo.all(query)
  end

  defp child_ids(parent_id) do
    Repo.all(from t in Trait, where: t.parent_trait_id == ^int(parent_id), select: t.id)
  end

  defp active_child_ids(parent_id) do
    Repo.all(
      from t in Trait,
        where: t.parent_trait_id == ^int(parent_id) and t.is_active == true,
        select: t.id
    )
  end

  defp exclusive_among(ids, pairs \\ nil) do
    pairs = pairs || conflict_pairs(ids)

    if length(ids) < 2 do
      []
    else
      Enum.filter(ids, fn id ->
        Enum.all?(ids -- [id], fn other ->
          {left, right} = if id > other, do: {other, id}, else: {id, other}
          MapSet.member?(pairs, {left, right})
        end)
      end)
    end
  end

  defp conflict_pairs([]), do: MapSet.new()

  defp conflict_pairs(ids) do
    Repo.all(
      from r in TraitRelationship,
        where: r.kind == "conflicts" and r.trait_id in ^ids and r.related_trait_id in ^ids,
        select: {r.trait_id, r.related_trait_id}
    )
    |> MapSet.new()
  end

  defp kind_filter(query, nil), do: query
  defp kind_filter(query, ""), do: query
  defp kind_filter(query, kind), do: where(query, [r], r.kind == ^kind)

  defp int(value) when is_integer(value), do: value

  defp int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil

  defp family_ids(parent_id) do
    children =
      Repo.all(from t in Trait, where: t.parent_trait_id == ^parent_id, select: t.id)

    [parent_id | children]
  end
end
