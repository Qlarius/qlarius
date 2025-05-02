defmodule Qlarius.Traits do
  import Ecto.Query

  alias Qlarius.Accounts.MeFile
  alias Qlarius.Accounts.User
  alias Qlarius.Campaigns.TraitGroup
  alias Qlarius.Repo
  alias Qlarius.Surveys.Survey
  alias Qlarius.Surveys.SurveyCategory
  alias Qlarius.Traits.MeFileTag
  alias Qlarius.Traits.Trait
  alias Qlarius.Traits.TraitCategory
  alias Qlarius.Traits.TraitValue

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

  def create_user_trait_values(user_id, trait_id, value_ids) when is_list(value_ids) do
    user = Repo.get!(User, user_id) |> Repo.preload(:me_file)

    # Start a transaction
    Repo.transaction(fn ->
      # Delete existing tags for this trait
      delete_trait_tags(trait_id, user_id)

      # Create new tags
      value_ids
      |> Enum.map(fn value_id ->
        %MeFileTag{}
        |> MeFileTag.changeset(%{me_file_id: user.me_file.id, trait_value_id: value_id})
        |> Repo.insert!()
      end)
    end)
  end

  @doc """
  Deletes all MeFileTags for a given trait and user.
  """
  def delete_trait_tags(trait_id, user_id) do
    from(tag in MeFileTag,
      join: traitval in TraitValue,
      on: tag.trait_value_id == traitval.id,
      join: mefile in MeFile,
      on: mefile.id == tag.me_file_id,
      where: traitval.trait_id == ^trait_id and mefile.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets all trait values that a user has selected for a given trait.
  """
  def get_user_trait_values(trait_id, user_id) do
    from(tag in MeFileTag,
      join: traitval in TraitValue,
      on: tag.trait_value_id == traitval.id,
      join: mefile in MeFile,
      on: mefile.id == tag.me_file_id,
      where: traitval.trait_id == ^trait_id and mefile.user_id == ^user_id,
      select: traitval.id
    )
    |> Repo.all()
  end

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
             ut.trait_value_id in fragment("SELECT id FROM trait_values WHERE parent_trait_id = ?", t.id),
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
    query =
      from u in Qlarius.Accounts.User,
      join: mf in Qlarius.Accounts.MeFile, on: mf.user_id == u.id,
      join: mft in Qlarius.Traits.MeFileTag, on: mft.me_file_id == mf.id,
      join: tv in Qlarius.Traits.TraitValue, on: tv.id == mft.trait_id,
      join: t in Qlarius.Traits.Trait, on: t.id == tv.trait_id,
      where: u.id == ^user_id,
      select: count(t.id, :distinct)

    Qlarius.Repo.one(query)
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
  Gets all survey categories with their surveys and completion stats for a user.
  Categories and surveys are ordered by display_order.
  """
  def list_survey_categories_with_stats(user_id) do
    SurveyCategory
    |> order_by([c], asc: c.display_order)
    |> preload(
      surveys:
        ^from(s in Survey,
          where: s.active == true,
          order_by: [asc: s.display_order],
          preload: [:traits]
        )
    )
    |> Repo.all()
    |> Enum.map(&add_completion_stats(&1, user_id))
  end

  defp add_completion_stats(category, user_id) do
    total_questions = Enum.reduce(category.surveys, 0, &(&2 + length(&1.traits)))
    completed_questions = count_completed_questions(category.surveys, user_id)

    surveys_with_stats =
      Enum.map(category.surveys, fn survey ->
        survey_completed = count_completed_questions([survey], user_id)
        survey_total = length(survey.traits)

        Map.merge(survey, %{
          completed_questions: survey_completed,
          total_questions: survey_total,
          completion_percentage:
            if(survey_total > 0, do: survey_completed / survey_total * 100, else: 0)
        })
      end)

    Map.merge(category, %{
      surveys: surveys_with_stats,
      completed_questions: completed_questions,
      total_questions: total_questions,
      completion_percentage:
        if(total_questions > 0, do: completed_questions / total_questions * 100, else: 0)
    })
  end

  @doc """
  Counts the number of completed questions (traits with answers) for a list of surveys and a user.
  Returns 0 if no questions are completed.
  """
  def count_completed_questions(surveys, user_id) do
    trait_ids = surveys |> Enum.flat_map(& &1.traits) |> Enum.map(& &1.id)

    from(t in Trait,
      join: tv in TraitValue,
      on: tv.trait_id == t.id,
      join: ut in UserTag,
      on: ut.trait_value_id == tv.id,
      where: t.id in ^trait_ids and ut.user_id == ^user_id,
      select: count(fragment("DISTINCT ?", t.id))
    )
    |> Repo.one() || 0
  end
end
