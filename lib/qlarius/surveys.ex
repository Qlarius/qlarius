defmodule Qlarius.Surveys do
  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Surveys.SurveyCategory
  alias Qlarius.Surveys.Survey

  # Survey Category functions

  def list_survey_categories do
    Repo.all(from c in SurveyCategory, order_by: c.display_order)
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
    user = Repo.get!(User, user_id) |> Repo.preload(:me_file)

    trait_ids = surveys |> Enum.flat_map(& &1.traits) |> Enum.map(& &1.id)

    from(t in Trait,
      join: tv in TraitValue,
      on: tv.trait_id == t.id,
      join: mft in MeFileTag,
      on: mft.trait_id == tv.id,
      where: t.id in ^trait_ids and mft.me_file_id == ^user.me_file.id,
      select: count(fragment("DISTINCT ?", t.id))
    )
    |> Repo.one() || 0
  end

  def get_survey_category!(id), do: Repo.get!(SurveyCategory, id)

  def create_survey_category(attrs \\ %{}) do
    %SurveyCategory{}
    |> SurveyCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey_category(%SurveyCategory{} = survey_category, attrs) do
    survey_category
    |> SurveyCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_survey_category(%SurveyCategory{} = survey_category) do
    Repo.delete(survey_category)
  end

  def change_survey_category(%SurveyCategory{} = survey_category, attrs \\ %{}) do
    SurveyCategory.changeset(survey_category, attrs)
  end

  # Survey functions

  def list_surveys do
    Repo.all(from s in Survey, order_by: s.display_order, preload: :category)
  end

  def list_surveys_by_category do
    values_query = from v in Qlarius.Traits.TraitValue, order_by: v.display_order
    traits_query = from t in Qlarius.Traits.Trait, preload: [values: ^values_query]
    surveys_query = from s in Survey, order_by: s.display_order, preload: [traits: ^traits_query]

    query =
      from c in SurveyCategory,
        order_by: c.display_order,
        preload: [surveys: ^surveys_query]

    Repo.all(query)
  end

  def get_survey!(id) do
    Repo.get!(Survey, id)
    |> Repo.preload([
      :category,
      traits: [values: from(v in Qlarius.Traits.TraitValue, order_by: v.display_order)]
    ])
  end

  def create_survey(attrs \\ %{}) do
    %Survey{}
    |> Survey.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey(%Survey{} = survey, attrs) do
    survey
    |> Survey.changeset(attrs)
    |> Repo.update()
  end

  def delete_survey(%Survey{} = survey) do
    Repo.delete(survey)
  end

  def change_survey(%Survey{} = survey, attrs \\ %{}) do
    Survey.changeset(survey, attrs)
  end
end
