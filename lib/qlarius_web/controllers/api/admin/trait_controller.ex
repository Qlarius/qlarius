defmodule QlariusWeb.Api.Admin.TraitController do
  use QlariusWeb, :controller

  alias Qlarius.YouData.TraitBulk
  alias Qlarius.YouData.TraitDesign
  alias Qlarius.YouData.TraitGuards
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.TraitSearch
  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.TraitRelationships
  alias QlariusWeb.Api.Admin.Responder

  def index(conn, params) do
    scope = conn.assigns.current_scope

    parents =
      TraitManager.list_parents(scope,
        q: params["q"] || "",
        category_id: integer(params["category_id"]),
        include_inactive: truthy?(params["include_inactive"])
      )

    json(conn, %{
      traits:
        Enum.map(parents, fn trait ->
          %{
            id: trait.id,
            trait_name: trait.trait_name,
            input_type: trait.input_type,
            is_active: trait.is_active,
            display_order: trait.display_order,
            trait_category_id: trait.trait_category_id,
            meta_1: trait.meta_1,
            meta_2: trait.meta_2,
            meta_3: trait.meta_3,
            has_search_filter: trait.has_search_filter,
            search_terms: trait.search_terms
          }
        end)
    })
  end

  def catalog(conn, _params) do
    json(conn, %{trait_categories: Traits.traits_catalog()})
  end

  # Same ranking the Builder (scope=builder, top 15 surveyed traits) and Qai
  # (scope=all, top 10 active traits) use, including the score and the field
  # each query word hit.
  def search(conn, params) do
    case search_scope(params["scope"]) do
      {:ok, opts, limit} ->
        results =
          case TraitSearch.tokenize(params["q"] || "") do
            {:ok, tokens} -> tokens |> TraitSearch.rank(opts) |> Enum.take(limit)
            {:error, :empty_query} -> []
          end

        json(conn, %{results: results})

      :error ->
        conn
        |> put_status(422)
        |> json(%{
          error: "invalid_scope",
          message: "scope must be builder or all"
        })
    end
  end

  defp search_scope(nil), do: {:ok, [], 10}
  defp search_scope("all"), do: {:ok, [], 10}
  defp search_scope("builder"), do: {:ok, [surveyed_only: true], 15}
  defp search_scope(_), do: :error

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(trait) do
      json(conn, parent_json(TraitManager.get_parent_trait_with_details(scope, id)))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id) do
      if is_nil(trait.parent_trait_id) do
        with :ok <- TraitGuards.ensure_input_type_change(trait, params["input_type"], force),
             {:ok, trait} <- TraitManager.update_parent_trait(scope, trait, parent_attrs(params)) do
          json(
            conn,
            parent_json(TraitManager.get_parent_trait_with_details(scope, id))
            |> Map.put(:inserted_children, brief_children(trait.inserted_children))
          )
        else
          {:error, reason} -> Responder.error(conn, reason)
        end
      else
        with {:ok, parent} <- TraitManager.fetch_trait(scope, trait.parent_trait_id),
             :ok <- parent_only(parent),
             :ok <- TraitGuards.ensure_child_mutation(parent, force),
             {:ok, child} <- TraitManager.update_child_trait(scope, trait, child_attrs(params)) do
          json(conn, child_json(child))
        else
          {:error, reason} -> Responder.error(conn, reason)
        end
      end
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create_children(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])
    children = params["children"] || []

    with {:ok, parent} <- TraitManager.fetch_trait(scope, id),
         :ok <- no_children_of_children(parent),
         :ok <- TraitGuards.ensure_child_mutation(parent, force),
         {:ok, created} <- insert_children(scope, parent, children),
         {:ok, inserted_skip} <- TraitManager.ensure_skipped_child(scope, parent) do
      new_ids =
        Enum.map(created, & &1.id) ++
          case inserted_skip do
            %{id: id} -> [id]
            _ -> []
          end

      links =
        if params["extend_exclusive_conflicts"] in [false, "false", "0", 0] do
          []
        else
          TraitRelationships.extend_exclusive_conflicts(parent.id, new_ids)
        end

      conn
      |> put_status(201)
      |> json(%{
        children:
          Enum.map(created, fn child ->
            %{
              id: child.id,
              trait_name: child.trait_name,
              display_order: child.display_order,
              meta_1: child.meta_1,
              meta_2: child.meta_2,
              meta_3: child.meta_3,
              search_terms: child.search_terms,
              is_exclusive: child.is_exclusive,
              is_skipped_tag: child.is_skipped_tag
            }
          end),
        inserted_children: brief_children(inserted_skip),
        inserted_relationships: Enum.map(links, &TraitRelationships.to_json/1)
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def make_exclusive(conn, %{"id" => parent_id, "child_id" => child_id} = params) do
    opts = [
      note: params["note"],
      include_inactive: truthy?(params["include_inactive"]),
      exclude_skip: exclude_skip?(params)
    ]

    case TraitRelationships.make_exclusive(parent_id, child_id, opts) do
      {:ok, summary} -> json(conn, summary)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def unmake_exclusive(conn, %{"id" => parent_id, "child_id" => child_id}) do
    case TraitRelationships.unmake_exclusive(parent_id, child_id) do
      {:ok, summary} -> json(conn, summary)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def bulk_rules(conn, params) do
    write_bulk(conn, TraitBulk.apply_rules(conn.assigns.current_scope, params))
  end

  def bulk_search_terms(conn, params) do
    write_bulk(conn, TraitBulk.apply_search_terms(conn.assigns.current_scope, params))
  end

  defp write_bulk(conn, {:ok, body}), do: json(conn, body)

  defp write_bulk(conn, {:error, reason}) when is_atom(reason), do: Responder.error(conn, reason)

  defp write_bulk(conn, {:error, body}) do
    conn |> put_status(422) |> json(Map.put(body, :error, "invalid"))
  end

  def update_child(conn, %{"id" => id, "child_id" => child_id} = params) do
    scope = conn.assigns.current_scope
    force = truthy?(params["force"])

    with {:ok, parent} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(parent),
         :ok <- TraitGuards.ensure_child_mutation(parent, force),
         {:ok, child} <- TraitManager.fetch_trait(scope, child_id),
         :ok <- child_of(parent, child),
         {:ok, child} <- TraitManager.update_child_trait(scope, child, child_attrs(params)) do
      json(conn, child_json(child))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def deactivate(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         {:ok, trait} <- TraitManager.deactivate_trait(scope, trait) do
      json(conn, %{id: trait.id, is_active: trait.is_active})
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def integrity_report(conn, params) do
    json(conn, Qlarius.YouData.TraitIntegrity.report(skip_rate_threshold: threshold(params)))
  end

  def lookup(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, trait} <- TraitManager.fetch_trait(scope, id),
         :ok <- parent_only(trait) do
      json(conn, %{
        children: Traits.search_children(trait.id, params["q"] || "", integer(params["limit"]))
      })
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def design_pack(conn, params) do
    case TraitDesign.apply(conn.assigns.current_scope, params) do
      {:ok, detail} -> json(conn, detail)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp insert_children(scope, parent, children) when is_list(children) and children != [] do
    Enum.reduce_while(children, {:ok, []}, fn child, {:ok, acc} ->
      name = child["trait_name"]

      cond do
        name in [nil, ""] or
            (is_binary(name) and (String.trim(name) == "" or String.length(name) > 256)) ->
          {:halt, {:error, :invalid_trait_name}}

        true ->
          case TraitManager.create_child_trait(scope, parent, child_write_attrs(child, name)) do
            {:ok, created} -> {:cont, {:ok, acc ++ [created]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  defp insert_children(_scope, _parent, _), do: {:error, :empty_pack}

  defp parent_only(%{parent_trait_id: nil}), do: :ok
  defp parent_only(_), do: {:error, :not_a_parent}

  defp no_children_of_children(%{parent_trait_id: nil}), do: :ok
  defp no_children_of_children(_), do: {:error, :child_under_child}

  defp child_of(parent, %{parent_trait_id: parent_id}) when parent_id == parent.id, do: :ok
  defp child_of(_, _), do: {:error, :child_not_in_parent}

  defp child_write_attrs(child, name) do
    %{
      "trait_name" => String.trim(name),
      "display_order" => integer(child["display_order"])
    }
    |> put_meta(child)
    |> put_skip_flag(child)
    |> put_exclusive(child)
    |> put_search_terms(child)
  end

  defp put_exclusive(attrs, params) do
    if Map.has_key?(params, "is_exclusive") do
      Map.put(attrs, "is_exclusive", truthy?(params["is_exclusive"]))
    else
      attrs
    end
  end

  defp brief_children(nil), do: []

  defp brief_children(%{id: _} = child), do: brief_children([child])

  defp brief_children(children) when is_list(children) do
    Enum.map(children, fn child ->
      %{
        id: child.id,
        trait_name: child.trait_name,
        is_skipped_tag: child.is_skipped_tag,
        is_exclusive: child.is_exclusive,
        display_order: child.display_order
      }
    end)
  end

  defp child_json(child) do
    %{
      id: child.id,
      trait_name: child.trait_name,
      display_order: child.display_order,
      is_active: child.is_active,
      meta_1: child.meta_1,
      meta_2: child.meta_2,
      meta_3: child.meta_3,
      search_terms: child.search_terms,
      is_skipped_tag: child.is_skipped_tag,
      is_exclusive: child.is_exclusive
    }
  end

  defp put_skip_flag(attrs, params) do
    if Map.has_key?(params, "is_skipped_tag") do
      Map.put(attrs, "is_skipped_tag", truthy?(params["is_skipped_tag"]))
    else
      attrs
    end
  end

  defp parent_attrs(params) do
    params
    |> Map.take(["trait_name", "input_type", "trait_category_id", "display_order", "is_active"])
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Map.new()
    |> put_meta(params)
    |> put_search_filter(params)
    |> put_search_terms(params)
    |> put_quality(params)
    |> put_parent_controls(params)
  end

  defp put_parent_controls(attrs, params) do
    attrs =
      if Map.has_key?(params, "skip_exempt") do
        Map.put(attrs, "skip_exempt", truthy?(params["skip_exempt"]))
      else
        attrs
      end

    if Map.has_key?(params, "nudge_text") do
      Map.put(attrs, "nudge_text", params["nudge_text"])
    else
      attrs
    end
  end

  defp threshold(params) do
    raw = params["skip_rate_threshold"]

    value =
      cond do
        is_integer(raw) ->
          raw / 1

        is_float(raw) ->
          raw

        is_binary(raw) ->
          case Float.parse(raw) do
            {n, _} -> n
            :error -> 15.0
          end

        true ->
          15.0
      end

    if value <= 1, do: value, else: value / 100
  end

  defp parent_json(parent) do
    parent
    |> TraitDesign.parent_detail()
    |> Map.put(
      :relationships,
      parent.id
      |> TraitRelationships.list_for_parent()
      |> Enum.map(&TraitRelationships.to_json/1)
    )
  end

  @quality_keys ~w(ideal_min_tags ideal_max_tags hard_max_tags unripe_days ripen_days stale_days expired_days)

  # Sending a key replaces it. null clears it. Leaving the key out keeps it.
  defp put_quality(attrs, params) do
    Enum.reduce(@quality_keys, attrs, fn key, acc ->
      if Map.has_key?(params, key) do
        Map.put(acc, key, quality_value(params[key]))
      else
        acc
      end
    end)
  end

  defp quality_value(nil), do: nil
  defp quality_value(""), do: nil
  defp quality_value(value) when is_integer(value), do: value

  defp quality_value(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> value
    end
  end

  defp quality_value(value), do: value

  defp child_attrs(params) do
    params
    |> Map.take(["trait_name", "display_order", "is_active", "is_skipped_tag"])
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Map.new()
    |> put_meta(params)
    |> put_search_terms(params)
    |> put_exclusive(params)
    |> put_sent_count_rules(params)
  end

  defp put_sent_count_rules(attrs, params) do
    Enum.reduce(~w(ideal_min_tags ideal_max_tags hard_max_tags), attrs, fn key, acc ->
      if Map.has_key?(params, key), do: Map.put(acc, key, params[key]), else: acc
    end)
  end

  # Sent as given (a list, or one comma-separated string); `null` clears
  defp put_search_terms(attrs, params) do
    if Map.has_key?(params, "search_terms"),
      do: Map.put(attrs, "search_terms", params["search_terms"] || []),
      else: attrs
  end

  defp put_search_filter(attrs, params) do
    if Map.has_key?(params, "has_search_filter") do
      Map.put(attrs, "has_search_filter", truthy?(params["has_search_filter"]))
    else
      attrs
    end
  end

  defp put_meta(attrs, params) do
    Enum.reduce(["meta_1", "meta_2", "meta_3"], attrs, fn key, acc ->
      if Map.has_key?(params, key) do
        Map.put(acc, key, meta_value(params[key]))
      else
        acc
      end
    end)
  end

  defp meta_value(nil), do: nil

  defp meta_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp meta_value(_), do: nil

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp exclude_skip?(params) when is_map(params) do
    case Map.get(params, "exclude_skip") do
      nil -> true
      value -> truthy?(value)
    end
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
