defmodule Qlarius.X.Traits do
  @moduledoc """
  The Traits context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Traits.Trait
  alias Qlarius.Traits.TraitCategory
  alias Qlarius.Traits.TraitValue
  alias Qlarius.Campaigns.TraitGroup

  # TraitCategory functions

  @doc """
  Returns the list of trait categories sorted by display_order.
  """
  def list_trait_categories do
    Repo.all(from c in TraitCategory, order_by: c.display_order)
  end

  @doc """
  Gets a single trait_category.

  Raises `Ecto.NoResultsError` if the Trait category does not exist.
  """
  def get_trait_category!(id), do: Repo.get!(TraitCategory, id)

  @doc """
  Creates a trait_category.
  """
  def create_trait_category(attrs \\ %{}) do
    %TraitCategory{}
    |> TraitCategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trait_category.
  """
  def update_trait_category(%TraitCategory{} = trait_category, attrs) do
    trait_category
    |> TraitCategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trait_category.
  """
  def delete_trait_category(%TraitCategory{} = trait_category) do
    Repo.delete(trait_category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trait_category changes.
  """
  def change_trait_category(%TraitCategory{} = trait_category, attrs \\ %{}) do
    TraitCategory.changeset(trait_category, attrs)
  end

  # Trait functions

  @doc """
  Returns the list of traits ordered by name.
  """
  def list_traits do
    Repo.all(from t in Trait, order_by: t.name)
  end

  @doc """
  Gets a single trait.

  Raises `Ecto.NoResultsError` if the Trait does not exist.
  """
  def get_trait!(id), do: Repo.get!(Trait, id)

  @doc """
  Gets a single trait with preloaded values ordered by display_order.
  """
  def get_trait_with_values!(id) do
    Repo.get!(Trait, id)
    |> Repo.preload(values: from(v in TraitValue, order_by: v.display_order))
  end

  @doc """
  Creates a trait.
  """
  def create_trait(attrs \\ %{}) do
    %Trait{}
    |> Trait.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trait.
  """
  def update_trait(%Trait{} = trait, attrs) do
    trait
    |> Trait.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trait.
  """
  def delete_trait(%Trait{} = trait) do
    Repo.delete(trait)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trait changes.
  """
  def change_trait(%Trait{} = trait, attrs \\ %{}) do
    Trait.changeset(trait, attrs)
  end

  # TraitValue functions

  @doc """
  Gets a single trait value.

  Raises `Ecto.NoResultsError` if the Trait value does not exist.
  """
  def get_trait_value!(id), do: Repo.get!(TraitValue, id)

  @doc """
  Updates a trait value.
  """
  def update_trait_value(%TraitValue{} = trait_value, attrs) do
    trait_value
    |> TraitValue.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a trait value.
  """
  def create_trait_value(attrs \\ %{}) do
    %TraitValue{}
    |> TraitValue.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a trait value.
  """
  def delete_trait_value(%TraitValue{} = trait_value) do
    Repo.delete(trait_value)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trait value changes.
  """
  def change_trait_value(%TraitValue{} = trait_value, attrs \\ %{}) do
    TraitValue.changeset(trait_value, attrs)
  end

  # TraitGroup functions

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
  Returns the list of trait categories with their associated traits.
  """
  def list_categories_with_traits do
    traits_query = from t in Trait, order_by: t.display_order

    Repo.all(
      from c in TraitCategory,
        order_by: c.display_order,
        preload: [traits: ^traits_query]
    )
  end

  @doc """
  Removes a trait from a survey.
  """
  def remove_trait_from_survey(survey, trait) do
    Repo.delete_all(
      from ts in "traits_surveys",
        where: ts.survey_id == ^survey.id and ts.trait_id == ^trait.id
    )

    {:ok, survey}
  end

  @doc """
  Returns traits grouped by category that are not in the given survey.
  Only includes categories that have at least one trait not in the survey.
  Categories and traits are ordered by display_order.
  """
  def list_available_traits_by_category(survey_id) when is_binary(survey_id) do
    list_available_traits_by_category(String.to_integer(survey_id))
  end

  def list_available_traits_by_category(survey_id) when is_integer(survey_id) do
    query =
      from t in Trait,
        left_join: ts in "traits_surveys",
        on: ts.trait_id == t.id and ts.survey_id == ^survey_id,
        where: is_nil(ts.survey_id),
        order_by: t.display_order,
        preload: [:category]

    traits = Repo.all(query)

    traits
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {category, _} -> category.display_order end)
  end

  @doc """
  Adds a trait to a survey.
  """
  def add_trait_to_survey(survey_id, trait_id) when is_binary(survey_id) do
    add_trait_to_survey(String.to_integer(survey_id), trait_id)
  end

  def add_trait_to_survey(survey_id, trait_id) when is_binary(trait_id) do
    add_trait_to_survey(survey_id, String.to_integer(trait_id))
  end

  def add_trait_to_survey(survey_id, trait_id)
      when is_integer(survey_id) and is_integer(trait_id) do
    Repo.insert_all("traits_surveys", [
      %{
        survey_id: survey_id,
        trait_id: trait_id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    ])

    {:ok, survey_id}
  end
end
