defmodule Qlarius.YouData.TraitBulk do
  @moduledoc """
  All-or-nothing rule and search-term updates. Nothing here inserts a skip child.
  """

  alias Qlarius.Repo
  alias Qlarius.YouData.TraitManager
  alias Qlarius.YouData.Traits.Trait

  @max_items 1000
  @rule_keys ~w(ideal_min_tags ideal_max_tags hard_max_tags unripe_days ripen_days stale_days expired_days skip_exempt nudge_text)

  def apply_rules(scope, params) when is_map(params) do
    items = params["items"] || []

    cond do
      not is_list(items) ->
        {:error, :invalid_payload}

      length(items) > @max_items ->
        {:error, :too_many_operations}

      true ->
        transact(params, fn -> Enum.map(items, &rule_item(scope, &1)) end)
    end
  end

  def apply_search_terms(scope, params) when is_map(params) do
    items = params["items"] || []

    cond do
      not is_list(items) ->
        {:error, :invalid_payload}

      length(items) > @max_items ->
        {:error, :too_many_operations}

      true ->
        transact(params, fn -> Enum.map(items, &search_item(scope, &1)) end)
    end
  end

  defp rule_item(scope, item) when is_map(item) do
    case Repo.get(Trait, int(item["trait_id"])) do
      nil ->
        %{status: "error", trait_id: int(item["trait_id"]), errors: %{"trait_id" => ["not found"]}}

      %Trait{parent_trait_id: parent} when not is_nil(parent) ->
        %{status: "error", trait_id: int(item["trait_id"]), errors: %{"trait_id" => ["not a parent"]}}

      %Trait{} = trait ->
        attrs = rule_attrs(item)

        case TraitManager.update_parent_trait(scope, trait, attrs, ensure_skip: false) do
          {:ok, updated} ->
            %{status: "updated", trait_id: updated.id}

          {:error, %Ecto.Changeset{} = changeset} ->
            %{status: "error", trait_id: trait.id, errors: errors_of(changeset)}
        end
    end
  end

  defp rule_item(_scope, _), do: %{status: "error", errors: %{"item" => ["must be an object"]}}

  defp search_item(scope, item) when is_map(item) do
    with {:ok, trait} <- search_target(item) do
      attrs = %{"search_terms" => item["search_terms"] || []}

      result =
        if is_nil(trait.parent_trait_id) do
          TraitManager.update_parent_trait(scope, trait, attrs, ensure_skip: false)
        else
          TraitManager.update_child_trait(scope, trait, attrs)
        end

      case result do
        {:ok, updated} -> %{status: "updated", trait_id: updated.id, search_terms: updated.search_terms}
        {:error, %Ecto.Changeset{} = changeset} ->
          %{status: "error", trait_id: trait.id, errors: errors_of(changeset)}
      end
    else
      {:error, row} -> row
    end
  end

  defp search_item(_scope, _), do: %{status: "error", errors: %{"item" => ["must be an object"]}}

  defp search_target(item) do
    trait_id = int(item["trait_id"])
    child_id = int(item["child_id"])

    cond do
      is_nil(trait_id) ->
        {:error, %{status: "error", errors: %{"trait_id" => ["is required"]}}}

      is_integer(child_id) ->
        case Repo.get(Trait, child_id) do
          %Trait{parent_trait_id: ^trait_id} = child -> {:ok, child}
          %Trait{} -> {:error, %{status: "error", trait_id: child_id, errors: %{"child_id" => ["not a child of trait_id"]}}}
          nil -> {:error, %{status: "error", trait_id: child_id, errors: %{"child_id" => ["not found"]}}}
        end

      true ->
        case Repo.get(Trait, trait_id) do
          %Trait{} = trait -> {:ok, trait}
          nil -> {:error, %{status: "error", trait_id: trait_id, errors: %{"trait_id" => ["not found"]}}}
        end
    end
  end

  defp rule_attrs(item) do
    Enum.reduce(@rule_keys, %{}, fn key, acc ->
      if Map.has_key?(item, key) do
        Map.put(acc, key, normalize_rule(key, item[key]))
      else
        acc
      end
    end)
  end

  defp normalize_rule("skip_exempt", value), do: value in [true, "true", "1", 1]
  defp normalize_rule("nudge_text", nil), do: nil
  defp normalize_rule(_key, nil), do: nil
  defp normalize_rule(_key, ""), do: nil
  defp normalize_rule(_key, value), do: value

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

  defp errors_of(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp int(value) when is_integer(value), do: value

  defp int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil
end
