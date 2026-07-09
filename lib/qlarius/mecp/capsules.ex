defmodule Qlarius.MeCP.Capsules do
  @moduledoc """
  Capsule compiler for the MeCP gateway.

  A capsule is a compact, deterministic rendering of a MeFile's tags, scoped to
  a grant, suitable for handing to a consuming model as context. Each tag value
  is annotated with the month/year it was confirmed (its `added_date`) so the
  consumer can reason about staleness.

  This module is a **pure function over preloaded data**: it performs no database
  access. Callers must preload the MeFile so that, for every tag, the trait, its
  parent trait, and the effective trait's category are available:

      Repo.preload(me_file,
        me_file_tags: [trait: [:trait_category, parent_trait: :trait_category]]
      )

  Two guarantees are property-tested (see the test module):

    * **Determinism** — the same MeFile + scope always renders byte-for-byte the
      same string, regardless of the order tags happen to be loaded in.
    * **Scope containment** — a capsule never contains a trait outside its scope.

  Tag freshness semantics are delete-and-rewrite, so `added_date` is always the
  confirmation date; no separate "last confirmed" concept is needed. Volatility
  classes are deferred, so every tag is rendered uniformly with its date.
  """

  alias Qlarius.MeCP.Capsules.{Capsule, Category, Scope, Trait, Value}
  alias Qlarius.YouData.MeFiles.MeFile

  @doc """
  Compiles a MeFile into a rendered capsule string for the given scope.

  Equivalent to `render(build(me_file, scope), opts)`. `scope` defaults to the
  full (unrestricted) scope; pass a `Scope` struct to restrict by category and/or
  trait ids.
  """
  @spec compile(MeFile.t(), Scope.t(), keyword()) :: String.t()
  def compile(%MeFile{} = me_file, %Scope{} = scope \\ Scope.all(), opts \\ []) do
    me_file
    |> build(scope)
    |> render(opts)
  end

  @doc """
  Builds the structured capsule (categories -> traits -> dated values) for a
  MeFile and scope, without rendering it to text.

  Only tags whose effective trait falls within `scope` are included. Values with
  no meaningful text are dropped. The result is fully ordered and deterministic.
  """
  @spec build(MeFile.t(), Scope.t()) :: Capsule.t()
  def build(%MeFile{} = me_file, %Scope{} = scope \\ Scope.all()) do
    categories =
      me_file.me_file_tags
      |> Enum.map(&resolve_tag/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn resolved -> Scope.allows?(scope, resolved) end)
      |> Enum.group_by(& &1.category_key)
      |> Enum.map(&build_category/1)
      |> Enum.sort_by(&category_sort_key/1)

    %Capsule{me_file_id: me_file.id, categories: categories}
  end

  @doc """
  Renders a built `Capsule` to a compact markdown string.

  Options:

    * `:title` — the top-level heading (default `"MeFile Context"`).
  """
  @spec render(Capsule.t(), keyword()) :: String.t()
  def render(%Capsule{} = capsule, opts \\ []) do
    title = Keyword.get(opts, :title, "MeFile Context")

    header = [
      "# #{title}",
      "",
      "_Self-declared by the MeFile owner. Dates show when each value was last confirmed._"
    ]

    body =
      case capsule.categories do
        [] -> ["", "No data in scope."]
        categories -> Enum.flat_map(categories, &render_category/1)
      end

    (header ++ body)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # --- resolution -----------------------------------------------------------

  # Mirrors MeFileTag.tag_with_full_data/1: when a tag's trait has a parent
  # trait, the parent is the effective trait and the child's name is the value;
  # otherwise the trait itself is effective and `tag_value` is the value. The
  # effective trait carries the category.
  defp resolve_tag(tag) do
    trait = loaded(tag.trait)

    {effective_trait, raw_value} =
      case trait && loaded(trait.parent_trait) do
        nil -> {trait, tag.tag_value}
        %{} = parent -> {parent, trait.trait_name}
      end

    with %{} <- effective_trait,
         text when is_binary(text) <- normalize_value(raw_value) do
      category = loaded(effective_trait.trait_category)
      {cat_id, cat_name, cat_order} = category_fields(category)

      %{
        category_key: cat_id,
        category_name: cat_name,
        category_order: cat_order,
        trait_id: effective_trait.id,
        trait_name: effective_trait.trait_name,
        trait_order: effective_trait.display_order,
        value: %Value{text: text, added_date: tag.added_date, tag_id: tag.id}
      }
    else
      _ -> nil
    end
  end

  # Treat an unloaded association (or nil) as absent, so a missing preload
  # degrades to "no parent / no category" rather than crashing.
  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(other), do: other

  defp normalize_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_value(_), do: nil

  defp category_fields(nil), do: {nil, "Uncategorized", nil}

  defp category_fields(category) do
    {category.id, category.name || "Uncategorized", Map.get(category, :display_order)}
  end

  # --- grouping / ordering --------------------------------------------------

  defp build_category({_cat_key, resolved_list}) do
    [first | _] = resolved_list

    traits =
      resolved_list
      |> Enum.group_by(& &1.trait_id)
      |> Enum.map(&build_trait/1)
      |> Enum.sort_by(&trait_sort_key/1)

    %Category{
      id: first.category_key,
      name: first.category_name,
      display_order: first.category_order,
      traits: traits
    }
  end

  defp build_trait({trait_id, resolved_list}) do
    [first | _] = resolved_list

    values =
      resolved_list
      |> Enum.map(& &1.value)
      |> Enum.sort_by(&value_sort_key/1)

    %Trait{
      id: trait_id,
      name: first.trait_name,
      display_order: first.trait_order,
      values: values
    }
  end

  @order_max 1_000_000_000

  defp category_sort_key(%Category{} = c),
    do: {c.display_order || @order_max, downcase(c.name), c.id || @order_max}

  defp trait_sort_key(%Trait{} = t),
    do: {t.display_order || @order_max, downcase(t.name), t.id || @order_max}

  # Exact text (not downcased) is the primary key so that values differing only
  # by case are never tied: a tie would make ordering depend on input order and
  # break determinism. `added_date` is compared as an ISO string rather than as
  # a struct, since term ordering of date structs is not chronological.
  defp value_sort_key(%Value{} = v),
    do: {v.text, date_key(v.added_date), v.tag_id || @order_max}

  defp date_key(nil), do: ""
  defp date_key(%Date{} = d), do: Date.to_iso8601(d)
  defp date_key(%NaiveDateTime{} = d), do: NaiveDateTime.to_iso8601(d)
  defp date_key(%DateTime{} = d), do: DateTime.to_iso8601(d)

  defp downcase(nil), do: ""
  defp downcase(str), do: String.downcase(str)

  # --- rendering ------------------------------------------------------------

  defp render_category(%Category{} = category) do
    ["", "## #{category.name}"] ++ Enum.flat_map(category.traits, &render_trait/1)
  end

  defp render_trait(%Trait{} = trait) do
    ["", "### #{trait.name}"] ++ Enum.map(trait.values, &render_value/1)
  end

  defp render_value(%Value{} = value) do
    case format_date(value.added_date) do
      nil -> "- #{value.text}"
      date -> "- #{value.text} (#{date})"
    end
  end

  defp format_date(nil), do: nil
  defp format_date(date), do: Calendar.strftime(date, "%b %Y")
end
