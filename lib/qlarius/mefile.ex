defmodule Qlarius.MeFile do
  import Ecto.Query, warn: false

  alias Qlarius.Repo
  alias Qlarius.Traits.{Trait, TraitCategory, TraitValue, UserTag}

  @doc """
  Gets all trait categories with their traits and values for a given user.
  Categories and traits are ordered by display_order.
  Only returns traits that have at least one value for the user.
  """
  def list_categories_with_traits(user_id) do
    TraitCategory
    |> order_by([c], asc: c.display_order)
    |> preload(
      traits:
        ^{from(t in Trait,
           join: ut in UserTag,
           on:
             ut.trait_value_id in fragment("SELECT id FROM trait_values WHERE trait_id = ?", t.id),
           where: ut.user_id == ^user_id,
           distinct: true,
           order_by: [asc: t.display_order]
         ), [values: values_for_user_query(user_id)]}
    )
    |> Repo.all()
    |> Enum.map(&filter_empty_traits/1)
  end

  @doc """
  Gets the total number of traits for which the user has at least one value.
  """
  def count_traits_with_values(user_id) do
    Trait
    |> join(:inner, [t], ut in UserTag,
      on:
        ut.trait_value_id in fragment("SELECT id FROM trait_values WHERE trait_id = ?", t.id) and
          ut.user_id == ^user_id
    )
    |> select([t], count(fragment("DISTINCT ?", t.id)))
    |> Repo.one()
  end

  @doc """
  Gets the total number of user tags.
  """
  def count_user_tags(user_id) do
    UserTag
    |> where([ut], ut.user_id == ^user_id)
    |> select([ut], count(ut.id))
    |> Repo.one()
  end

  defp values_for_user_query(user_id) do
    from(tv in TraitValue,
      join: ut in UserTag,
      on: ut.trait_value_id == tv.id and ut.user_id == ^user_id,
      order_by: [asc: tv.display_order]
    )
  end

  defp filter_empty_traits(category) do
    %{category | traits: Enum.filter(category.traits, &(length(&1.values) > 0))}
  end

  @doc """
  Deletes all UserTags for a given trait and user.
  Returns the number of tags deleted.
  """
  def delete_trait_tags(trait_id, user_id) do
    from(ut in UserTag,
      join: tv in TraitValue,
      on: ut.trait_value_id == tv.id,
      where: tv.trait_id == ^trait_id and ut.user_id == ^user_id
    )
    |> Repo.delete_all()
  end
end
