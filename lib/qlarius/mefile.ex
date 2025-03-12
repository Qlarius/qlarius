defmodule Qlarius.MeFile do
  import Ecto.Query, warn: false

  alias Qlarius.Repo
  alias Qlarius.Traits.{Trait, TraitCategory, TraitValue, UserTag}
  alias Qlarius.Surveys.{Survey, SurveyCategory}

  @doc """
  Creates UserTag records linking a user to selected trait values.
  Deletes any existing UserTags for this trait before creating new ones.
  """
  def create_user_trait_values(user_id, trait_id, value_ids) when is_list(value_ids) do
    # Start a transaction
    Repo.transaction(fn ->
      # Delete existing tags for this trait
      delete_trait_tags(trait_id, user_id)

      # Create new tags
      value_ids
      |> Enum.map(fn value_id ->
        %UserTag{}
        |> UserTag.changeset(%{user_id: user_id, trait_value_id: value_id})
        |> Repo.insert!()
      end)
    end)
  end

  @doc """
  Deletes all UserTags for a given trait and user.
  """
  def delete_trait_tags(trait_id, user_id) do
    from(ut in UserTag,
      join: tv in TraitValue,
      on: ut.trait_value_id == tv.id,
      where: tv.trait_id == ^trait_id and ut.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets all trait values that a user has selected for a given trait.
  """
  def get_user_trait_values(trait_id, user_id) do
    from(tv in TraitValue,
      join: ut in UserTag,
      on: ut.trait_value_id == tv.id,
      where: tv.trait_id == ^trait_id and ut.user_id == ^user_id,
      select: tv.id
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
