defmodule Qlarius.MeCP.Capsules.Scope do
  @moduledoc """
  A capsule scope: the allowlist that decides which traits a capsule may contain.

  Two independent axes, each either `:all` (unrestricted) or a list of ids:

    * `category_ids` — allowed trait-category ids
    * `trait_ids` — allowed (effective) trait ids

  Semantics are **intersection**: a tag is in scope only if its effective trait's
  category is allowed *and* its effective trait is allowed. `Scope.all/0` allows
  everything; restricting one axis while leaving the other `:all` scopes by that
  axis alone.

  This maps onto a `mecp_grants.scope` jsonb of the shape
  `%{"category_ids" => [...], "trait_ids" => [...]}`.
  """

  @type ids :: :all | [integer()]
  @type t :: %__MODULE__{category_ids: ids(), trait_ids: ids()}

  defstruct category_ids: :all, trait_ids: :all

  @doc "The unrestricted scope (everything allowed)."
  @spec all() :: t()
  def all, do: %__MODULE__{category_ids: :all, trait_ids: :all}

  @doc """
  Builds a scope from options. Omitted axes default to `:all`.

      Scope.new(category_ids: [1, 2])
      Scope.new(trait_ids: [10, 11])
      Scope.new(category_ids: [1], trait_ids: [10, 11])
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      category_ids: normalize(Keyword.get(opts, :category_ids, :all)),
      trait_ids: normalize(Keyword.get(opts, :trait_ids, :all))
    }
  end

  @doc """
  Builds a scope from a persisted grant scope map (string or atom keys).

      Scope.from_grant(%{"category_ids" => [1], "trait_ids" => [10]})
  """
  @spec from_grant(map()) :: t()
  def from_grant(scope) when is_map(scope) do
    %__MODULE__{
      category_ids: normalize(fetch(scope, :category_ids)),
      trait_ids: normalize(fetch(scope, :trait_ids))
    }
  end

  @doc """
  Whether a resolved tag (`%{category_key: id, trait_id: id}`) is within scope.
  """
  @spec allows?(t(), %{category_key: integer() | nil, trait_id: integer()}) :: boolean()
  def allows?(%__MODULE__{} = scope, %{category_key: category_id, trait_id: trait_id}) do
    axis_allows?(scope.category_ids, category_id) and axis_allows?(scope.trait_ids, trait_id)
  end

  defp axis_allows?(:all, _id), do: true
  defp axis_allows?(allowed, id) when is_list(allowed), do: id in allowed

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key), :all)
    end
  end

  defp normalize(:all), do: :all
  defp normalize(nil), do: :all
  defp normalize(list) when is_list(list), do: Enum.map(list, &to_integer/1)

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)
end
