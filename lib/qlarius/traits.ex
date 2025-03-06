defmodule Qlarius.Traits do
  @moduledoc """
  The Traits context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Traits.Trait
  alias Qlarius.Traits.TraitCategory
  alias Qlarius.Campaigns.TraitGroup

  @doc """
  Returns the list of trait groups with their associated traits.
  """
  def list_trait_groups do
    Repo.all(TraitGroup)
    |> Repo.preload(:traits)
  end

  @doc """
  Gets a single trait_group.
  """
  def get_trait_group!(id) do
    Repo.get!(TraitGroup, id)
    |> Repo.preload(:traits)
  end

  @doc """
  Creates a trait_group.
  """
  def create_trait_group(attrs \\ %{}) do
    %TraitGroup{}
    |> TraitGroup.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trait_group.
  """
  def update_trait_group(%TraitGroup{} = trait_group, attrs) do
    trait_group
    |> TraitGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trait_group.
  """
  def delete_trait_group(%TraitGroup{} = trait_group) do
    Repo.delete(trait_group)
  end

  def change_trait_group(%TraitGroup{} = trait_group, attrs \\ %{}) do
    TraitGroup.changeset(trait_group, attrs)
  end

  @doc """
  Returns the list of trait categories with their associated parent traits.
  """
  def list_categories_with_parent_traits do
    query =
      from c in TraitCategory,
        order_by: c.display_order,
        preload: [traits: ^parent_traits_query()]

    Repo.all(query)
  end

  @doc """
  Returns a query for parent traits (traits without a parent).
  """
  def parent_traits_query do
    from t in Trait,
      where: is_nil(t.parent_id),
      order_by: t.display_order
  end

  def get_parent_trait!(id) do
    Repo.one!(from t in Trait, where: t.id == ^id and is_nil(t.parent_id))
  end

  def list_child_traits(parent_id) do
    Repo.all(
      from t in Trait,
        where: t.parent_id == ^parent_id,
        order_by: t.display_order
    )
  end
end
