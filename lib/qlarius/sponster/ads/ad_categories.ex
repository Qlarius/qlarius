defmodule Qlarius.Sponster.Ads.AdCategories do
  @moduledoc """
  The flat Sponster ad taxonomy: one `AdCategory` row per subcategory, grouped
  by `category_id`, tracked by `cohort`.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategory, MediaPiece}

  @legacy_category_id "LEGACY"
  @new_category_prefix "SP"
  @cohort_alphabet ~c"abcdefghijkmnpqrstuvwxyz23456789"

  def legacy_category_id, do: @legacy_category_id

  def iab_attribution do
    "This taxonomy includes material from the IAB Tech Lab Ad Product Taxonomy 2.0, " <>
      "which is licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). " <>
      "Source: https://iabtechlab.com/standards/ad-product-taxonomy/"
  end

  ## Cohorts

  def new_cohort(date \\ Date.utc_today()) do
    suffix = for _ <- 1..4, into: "", do: <<Enum.random(@cohort_alphabet)>>
    Calendar.strftime(date, "%y%m%d") <> "-" <> suffix
  end

  def list_cohorts do
    from(c in AdCategory,
      group_by: c.cohort,
      order_by: [desc: fragment("? <> 'legacy'", c.cohort), desc: max(c.id)],
      select: %{cohort: c.cohort, count: count(c.id)}
    )
    |> Repo.all()
  end

  ## Reading

  def get_row!(id), do: Repo.get!(AdCategory, id)

  def get_by_row_id(row_id) when is_binary(row_id), do: Repo.get_by(AdCategory, row_id: row_id)
  def get_by_row_id(_), do: nil

  def list_rows(filters \\ %{}) do
    filters = normalize_filters(filters)

    AdCategory
    |> apply_filters(filters)
    |> apply_search(filters["q"])
    |> order_by([c], asc: c.sort_order, asc: c.id)
    |> Repo.all()
    |> put_counts()
    |> rank(filters["q"])
  end

  def search(q, filters \\ %{}), do: list_rows(Map.put(filters, "q", q))

  def group_rows(rows) do
    grouped = Enum.group_by(rows, & &1.category_id)

    rows
    |> Enum.map(& &1.category_id)
    |> Enum.uniq()
    |> Enum.map(fn category_id ->
      [first | _] = chunk = Map.fetch!(grouped, category_id)

      %{
        category_id: category_id,
        category_name: first.category_name,
        category_label: first.category_label,
        rows: chunk
      }
    end)
  end

  def list_categories do
    from(c in AdCategory,
      group_by: [c.category_id, c.category_name, c.category_label],
      order_by: min(c.sort_order),
      select: %{
        category_id: c.category_id,
        category_name: c.category_name,
        category_label: c.category_label,
        count: count(c.id)
      }
    )
    |> Repo.all()
  end

  def media_pieces_count(%AdCategory{id: id}) do
    Repo.aggregate(from(mp in MediaPiece, where: mp.ad_category_id == ^id), :count)
  end

  def picker_options(current_id \\ nil) do
    current_id = maybe_int(blank_to_nil(current_id)) || 0

    from(c in AdCategory,
      where: c.active or c.id == ^current_id,
      order_by: [asc: c.sort_order, asc: c.id]
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{
        value: row.id,
        label: row.ad_label,
        group: row.category_label,
        search_text: search_text(row)
      }
    end)
  end

  def search_text(%AdCategory{} = row) do
    [
      row.ad_label,
      row.category_name,
      row.category_label,
      row.row_id,
      row.meta_1,
      row.meta_2,
      row.meta_3
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.replace("|", " ")
    |> String.downcase()
  end

  def search_terms(q) when is_binary(q),
    do: q |> String.downcase() |> String.split(~r/\s+/, trim: true)

  def search_terms(_), do: []

  defp normalize_filters(filters) do
    Map.new(filters, fn {k, v} -> {to_string(k), v} end)
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {"category_id", id}, q when is_binary(id) and id != "" ->
        where(q, [c], c.category_id == ^id)

      {"cohort", cohort}, q when is_binary(cohort) and cohort != "" ->
        where(q, [c], c.cohort == ^cohort)

      {"active", active}, q when active in [true, "true"] ->
        where(q, [c], c.active)

      {"active", active}, q when active in [false, "false"] ->
        where(q, [c], not c.active)

      {"row_ids", ids}, q when is_list(ids) ->
        where(q, [c], c.row_id in ^ids)

      _, q ->
        q
    end)
  end

  defp apply_search(query, q) do
    Enum.reduce(search_terms(q), query, fn term, acc ->
      pattern = "%" <> escape_like(term) <> "%"

      where(
        acc,
        [c],
        ilike(
          fragment(
            "concat_ws(' ', ?, ?, ?, ?, ?, ?, ?)",
            c.ad_label,
            c.category_name,
            c.category_label,
            c.row_id,
            c.meta_1,
            c.meta_2,
            c.meta_3
          ),
          ^pattern
        )
      )
    end)
  end

  defp escape_like(term), do: String.replace(term, ~r/([\\%_])/, "\\\\\\1")

  defp rank(rows, q) do
    case search_terms(q) do
      [] ->
        rows

      terms ->
        {label_hits, others} =
          Enum.split_with(rows, fn row ->
            label = String.downcase(row.ad_label)
            Enum.all?(terms, &String.contains?(label, &1))
          end)

        label_hits ++ others
    end
  end

  defp put_counts([]), do: []

  defp put_counts(rows) do
    ids = Enum.map(rows, & &1.id)

    totals =
      from(mp in MediaPiece,
        where: mp.ad_category_id in ^ids,
        group_by: mp.ad_category_id,
        select: {mp.ad_category_id, count(mp.id)}
      )
      |> Repo.all()
      |> Map.new()

    actives =
      from(mp in MediaPiece,
        join: mr in assoc(mp, :media_runs),
        join: ms in assoc(mr, :media_sequence),
        join: c in assoc(ms, :campaigns),
        where: mp.ad_category_id in ^ids and is_nil(c.deactivated_at),
        group_by: mp.ad_category_id,
        select: {mp.ad_category_id, count(mp.id, :distinct)}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(rows, fn row ->
      %{
        row
        | media_pieces_count: Map.get(totals, row.id, 0),
          active_media_pieces_count: Map.get(actives, row.id, 0)
      }
    end)
  end

  ## Creating and editing

  def change_row(%AdCategory{} = row, attrs \\ %{}) do
    if row.id, do: AdCategory.changeset(row, attrs), else: AdCategory.create_changeset(row, attrs)
  end

  @doc """
  Creates one row. Pass `"category_id"` for an existing category, or
  `"new_category"` with `"category_name"` and `"category_label"` to start the
  next `SPnn` category. A missing cohort gets a fresh `new_cohort/0`.
  """
  def create_row(attrs) do
    attrs = stringify(attrs)

    Repo.transaction(fn ->
      with {:ok, category} <- resolve_category(attrs),
           cohort = blank_to_nil(attrs["cohort"]) || new_cohort(),
           {:ok, row} <- insert_in_category(category, attrs, cohort) do
        row
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Creates one row per non-blank line of `labels_text`, all in the category
  chosen by `attrs` (as in `create_row/1`) and sharing one cohort and the other
  fields in `attrs`. Rolls back everything if any label is invalid.
  """
  def create_rows(attrs, labels_text) when is_binary(labels_text) do
    attrs = attrs |> stringify() |> Map.drop(~w(ad_label sort_order))
    cohort = blank_to_nil(attrs["cohort"]) || new_cohort()

    labels =
      labels_text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    Repo.transaction(fn ->
      if labels == [], do: Repo.rollback(:no_labels)

      case resolve_category(attrs) do
        {:ok, category} ->
          labels
          |> Enum.map_reduce(category, fn label, category ->
            case insert_in_category(category, Map.put(attrs, "ad_label", label), cohort) do
              {:ok, row} -> {row, %{category | new?: false}}
              {:error, reason} -> Repo.rollback({label, reason})
            end
          end)
          |> elem(0)

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, %{cohort: cohort, rows: rows}}
      error -> error
    end
  end

  defp resolve_category(%{"new_category" => %{} = new}) do
    {:ok,
     %{
       category_id: next_category_id(),
       category_name: new["category_name"] || new[:category_name],
       category_label: new["category_label"] || new[:category_label],
       new?: true
     }}
  end

  defp resolve_category(%{"category_id" => category_id}) when is_binary(category_id) do
    case Repo.one(from c in AdCategory, where: c.category_id == ^category_id, limit: 1) do
      nil ->
        {:error, :unknown_category}

      row ->
        {:ok,
         %{
           category_id: row.category_id,
           category_name: row.category_name,
           category_label: row.category_label,
           new?: false
         }}
    end
  end

  defp resolve_category(_), do: {:error, :unknown_category}

  defp insert_in_category(category, attrs, cohort) do
    attrs =
      attrs
      |> Map.take(Enum.map(AdCategory.editable_fields(), &to_string/1))
      |> Map.merge(%{
        "row_id" => next_row_id(category.category_id),
        "category_id" => category.category_id,
        "category_name" => category.category_name,
        "category_label" => category.category_label,
        "cohort" => cohort
      })
      |> Map.put_new_lazy("sort_order", fn -> next_sort_order(category) end)

    %AdCategory{}
    |> AdCategory.create_changeset(attrs)
    |> Repo.insert()
  end

  def next_category_id do
    max =
      from(c in AdCategory,
        where: fragment("? ~ ?", c.category_id, ^"^#{@new_category_prefix}[0-9]+$"),
        select: max(fragment("substring(? from 3)::int", c.category_id))
      )
      |> Repo.one()

    @new_category_prefix <> String.pad_leading(Integer.to_string((max || 0) + 1), 2, "0")
  end

  def next_row_id(category_id) do
    suffixes =
      from(c in AdCategory,
        where: c.category_id == ^category_id,
        select: fragment("split_part(?, '-', 2)", c.row_id)
      )
      |> Repo.all()

    width = suffixes |> Enum.map(&String.length/1) |> Enum.max(fn -> 2 end) |> max(2)

    next =
      suffixes
      |> Enum.map(&parse_int/1)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(1)

    category_id <> "-" <> String.pad_leading(Integer.to_string(next), width, "0")
  end

  defp next_sort_order(%{new?: true}) do
    max =
      Repo.one(
        from c in AdCategory,
          where: c.category_id != ^@legacy_category_id,
          select: max(c.sort_order)
      )

    (max || 0) + 10
  end

  defp next_sort_order(%{category_id: category_id}) do
    max =
      Repo.one(
        from c in AdCategory, where: c.category_id == ^category_id, select: max(c.sort_order)
      )

    (max || 0) + 1
  end

  @doc """
  Updates the editable fields of a row. `row_id` and `category_id` can never
  change; category names change through `rename_category/2`.
  """
  def update_row(%AdCategory{} = row, attrs) do
    attrs = stringify(attrs)

    if immutable_change?(row, attrs) do
      {:error, :immutable_key}
    else
      row
      |> AdCategory.changeset(
        Map.drop(attrs, ~w(row_id category_id category_name category_label))
      )
      |> Repo.update()
    end
  end

  defp immutable_change?(row, attrs) do
    Enum.any?(~w(row_id category_id), fn key ->
      Map.has_key?(attrs, key) and attrs[key] != Map.fetch!(row, String.to_existing_atom(key))
    end)
  end

  def rename_category(category_id, attrs) do
    attrs = attrs |> stringify() |> Map.take(~w(category_name category_label))

    case Repo.one(from c in AdCategory, where: c.category_id == ^category_id, limit: 1) do
      nil ->
        {:error, :unknown_category}

      sample ->
        changeset = AdCategory.changeset(sample, attrs)

        if changeset.valid? do
          changes = Map.take(changeset.changes, [:category_name, :category_label])

          {count, _} =
            Repo.update_all(from(c in AdCategory, where: c.category_id == ^category_id),
              set: Enum.to_list(changes)
            )

          {:ok, %{category_id: category_id, updated: count}}
        else
          {:error, changeset}
        end
    end
  end

  ## Import

  @doc """
  Upserts CSV-shaped rows on `row_id`. Never deletes. Cohort is only set on
  insert. Options: `:cohort` (defaults to a fresh one), `:dry_run`.
  """
  def upsert_rows(rows, opts \\ []) when is_list(rows) do
    cohort = opts[:cohort] || new_cohort()
    dry_run = Keyword.get(opts, :dry_run, false)

    if AdCategory.valid_cohort?(cohort) do
      do_upsert(Enum.map(rows, &normalize_import_row/1), cohort, dry_run)
    else
      {:error, :invalid_cohort}
    end
  end

  defp do_upsert(rows, cohort, dry_run) do
    existing = Repo.all(AdCategory) |> Map.new(&{&1.row_id, &1})

    result =
      Repo.transaction(fn ->
        {counts, errors} =
          Enum.reduce(rows, {%{inserted: 0, updated: 0, unchanged: 0}, []}, fn row,
                                                                               {counts, errors} ->
            case upsert_one(row, Map.get(existing, row["row_id"]), cohort) do
              {:ok, kind} -> {Map.update!(counts, kind, &(&1 + 1)), errors}
              {:error, error} -> {counts, [error | errors]}
            end
          end)

        if errors != [], do: Repo.rollback({:invalid_rows, Enum.reverse(errors)})

        report = build_report(rows, existing, counts, cohort, dry_run)
        if dry_run, do: Repo.rollback({:dry_run, report}), else: report
      end)

    case result do
      {:ok, report} -> {:ok, report}
      {:error, {:dry_run, report}} -> {:ok, report}
      {:error, reason} -> {:error, reason}
    end
  end

  defp upsert_one(row, nil, cohort) do
    %AdCategory{}
    |> AdCategory.create_changeset(Map.put(row, "cohort", cohort))
    |> Repo.insert()
    |> case do
      {:ok, _} -> {:ok, :inserted}
      {:error, changeset} -> {:error, row_error(row, changeset)}
    end
  end

  defp upsert_one(row, existing, _cohort) do
    if row["category_id"] && row["category_id"] != existing.category_id do
      {:error, %{row_id: row["row_id"], errors: %{category_id: ["cannot change"]}}}
    else
      changeset = AdCategory.changeset(existing, Map.drop(row, ~w(cohort active)))

      cond do
        not changeset.valid? -> {:error, row_error(row, changeset)}
        changeset.changes == %{} -> {:ok, :unchanged}
        true -> update_imported(row, changeset)
      end
    end
  end

  defp update_imported(row, changeset) do
    case Repo.update(changeset) do
      {:ok, _} -> {:ok, :updated}
      {:error, changeset} -> {:error, row_error(row, changeset)}
    end
  end

  defp row_error(row, changeset) do
    %{row_id: row["row_id"], errors: changeset_errors(changeset)}
  end

  defp build_report(rows, existing, counts, cohort, dry_run) do
    input_ids = MapSet.new(rows, & &1["row_id"])

    {legacy, missing} =
      existing
      |> Map.values()
      |> Enum.reject(&MapSet.member?(input_ids, &1.row_id))
      |> Enum.split_with(&(&1.category_id == @legacy_category_id))

    Map.merge(counts, %{
      loaded: length(rows),
      missing: missing |> Enum.map(& &1.row_id) |> Enum.sort(),
      legacy_rows: length(legacy),
      cohort: cohort,
      dry_run: dry_run
    })
  end

  defp normalize_import_row(row) do
    row = stringify(row)

    row
    |> Map.take(~w(row_id category_id category_name category_label ad_label age_gated age_min
                   sales_channel_default meta_1 meta_2 meta_3 sort_order))
    |> Map.new(fn {k, v} -> {k, blank_to_nil(v)} end)
    |> Map.update("age_gated", false, &truthy?/1)
    |> Map.update("age_min", nil, &maybe_int/1)
    |> Map.update("sort_order", nil, &maybe_int/1)
  end

  defp truthy?(v) when v in [true, 1, "1", "true", "TRUE", "yes"], do: true
  defp truthy?(_), do: false

  defp maybe_int(nil), do: nil
  defp maybe_int(v) when is_integer(v), do: v
  defp maybe_int(v) when is_binary(v), do: parse_int(v)

  defp blank_to_nil(v) when is_binary(v) do
    case String.trim(v) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(v), do: v

  ## Cohort moves, remap, delete

  @doc "Moves rows to `cohort`. Selector: `\"row_ids\"` list or `\"category_id\"`."
  def set_cohort(selector, cohort) do
    selector = stringify(selector)

    cond do
      not AdCategory.valid_cohort?(cohort) ->
        {:error, :invalid_cohort}

      not selector_given?(selector, ~w(row_ids category_id)) ->
        {:error, :selector_required}

      true ->
        {count, _} =
          AdCategory
          |> apply_filters(Map.take(selector, ~w(row_ids category_id)))
          |> Repo.update_all(set: [cohort: cohort])

        {:ok, %{cohort: cohort, updated: count}}
    end
  end

  @doc """
  Moves media pieces to other rows in one transaction. Spec is either
  `%{"mappings" => [%{"from_row_id", "to_row_id"}]}` or
  `%{"media_piece_ids" => ids, "to_row_id" => row_id}`. Targets must be active.
  """
  def remap_media_pieces(spec, opts \\ []) do
    spec = stringify(spec)
    dry_run = Keyword.get(opts, :dry_run, false)

    result =
      Repo.transaction(fn ->
        mappings =
          spec
          |> remap_steps()
          |> Enum.map(fn step ->
            case run_remap_step(step) do
              {:ok, summary} -> summary
              {:error, reason} -> Repo.rollback(reason)
            end
          end)

        report = %{
          moved: mappings |> Enum.map(& &1.count) |> Enum.sum(),
          mappings: mappings,
          dry_run: dry_run
        }

        if dry_run, do: Repo.rollback({:dry_run, report}), else: report
      end)

    case result do
      {:ok, report} -> {:ok, report}
      {:error, {:dry_run, report}} -> {:ok, report}
      {:error, reason} -> {:error, reason}
    end
  end

  defp remap_steps(%{"mappings" => mappings}) when is_list(mappings) and mappings != [] do
    Enum.map(mappings, fn m ->
      m = stringify(m)
      {:rows, m["from_row_id"], m["to_row_id"]}
    end)
  end

  defp remap_steps(%{"media_piece_ids" => ids, "to_row_id" => to})
       when is_list(ids) and ids != [] do
    [{:pieces, Enum.map(ids, &maybe_int/1), to}]
  end

  defp remap_steps(_), do: Repo.rollback(:invalid_remap)

  defp run_remap_step({:rows, from_id, to_id}) do
    with {:ok, from} <- fetch_row(from_id),
         {:ok, to} <- fetch_target(to_id) do
      {count, _} =
        Repo.update_all(from(mp in MediaPiece, where: mp.ad_category_id == ^from.id),
          set: [ad_category_id: to.id]
        )

      {:ok, %{from_row_id: from.row_id, to_row_id: to.row_id, count: count}}
    end
  end

  defp run_remap_step({:pieces, ids, to_id}) do
    with {:ok, to} <- fetch_target(to_id) do
      {count, _} =
        Repo.update_all(from(mp in MediaPiece, where: mp.id in ^ids),
          set: [ad_category_id: to.id]
        )

      {:ok, %{media_piece_ids: ids, to_row_id: to.row_id, count: count}}
    end
  end

  defp fetch_row(row_id) do
    case get_by_row_id(row_id) do
      nil -> {:error, {:not_found, row_id}}
      row -> {:ok, row}
    end
  end

  defp fetch_target(row_id) do
    with {:ok, row} <- fetch_row(row_id) do
      if row.active, do: {:ok, row}, else: {:error, {:row_inactive, row_id}}
    end
  end

  @doc """
  Deletes rows with no media pieces of any status. Selector keys: `"row_ids"`,
  `"category_id"`, `"cohort"`, `"active"`, `"q"`, or `"all" => true`.
  """
  def prune_unused(selector, opts \\ []) do
    selector = stringify(selector)
    dry_run = Keyword.get(opts, :dry_run, false)

    if selector["all"] in [true, "true"] or
         selector_given?(selector, ~w(row_ids category_id cohort q)) do
      unused =
        from mp in MediaPiece, where: mp.ad_category_id == parent_as(:row).id, select: 1

      candidates =
        from(c in AdCategory, as: :row)
        |> apply_filters(selector)
        |> apply_search(selector["q"])
        |> where([c], not exists(unused))
        |> order_by([c], asc: c.sort_order)
        |> select([c], %{id: c.id, row_id: c.row_id})
        |> Repo.all()

      unless dry_run do
        ids = Enum.map(candidates, & &1.id)
        Repo.delete_all(from c in AdCategory, where: c.id in ^ids)
      end

      {:ok,
       %{deleted: Enum.map(candidates, & &1.row_id), count: length(candidates), dry_run: dry_run}}
    else
      {:error, :selector_required}
    end
  end

  def delete_row(%AdCategory{} = row) do
    case media_pieces_count(row) do
      0 -> Repo.delete(row)
      count -> {:error, {:in_use, count}}
    end
  end

  ## Helpers

  def changeset_errors(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp selector_given?(selector, keys) do
    Enum.any?(keys, fn key ->
      case selector[key] do
        nil -> false
        "" -> false
        [] -> false
        _ -> true
      end
    end)
  end

  defp stringify(%{} = map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
  defp stringify(_), do: %{}

  defp parse_int(v) do
    case Integer.parse(to_string(v)) do
      {n, _} -> n
      :error -> 0
    end
  end
end
