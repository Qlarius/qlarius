defmodule Qlarius.YouData.Surveys do
  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.YouData.Surveys.SurveyCategory
  alias Qlarius.YouData.Surveys.Survey
  alias Qlarius.YouData.Surveys.SurveyQuestion
  alias Qlarius.YouData.Surveys.SurveyAnswer

  # Survey Category functions

  def list_survey_categories do
    Repo.all(from c in SurveyCategory, order_by: c.display_order)
  end

  def list_survey_categories_with_surveys do
    surveys_query = from(s in Survey, order_by: s.display_order)

    Repo.all(
      from c in SurveyCategory, order_by: c.display_order, preload: [surveys: ^surveys_query]
    )
  end

  def list_survey_categories_with_surveys_and_stats(me_file_id) do
    surveys_query = from(s in Survey, order_by: s.display_order)

    Repo.all(
      from c in SurveyCategory,
        order_by: c.display_order,
        preload: [surveys: ^surveys_query]
    )
    |> Enum.map(&add_survey_question_ids(&1))
    |> Enum.map(&add_survey_stats(&1, []))
  end

  # Preferred variant: pass in precomputed answered_survey_question_ids to avoid DB trips
  def list_survey_categories_with_surveys_and_stats(me_file_id, answered_survey_question_ids) do
    surveys_query = from(s in Survey, order_by: s.display_order)

    Repo.all(
      from c in SurveyCategory,
        order_by: c.display_order,
        preload: [surveys: ^surveys_query]
    )
    |> Enum.map(&add_survey_question_ids(&1))
    |> Enum.map(&add_survey_stats(&1, answered_survey_question_ids))
  end

  defp add_survey_question_ids(category) do
    surveys_with_ids =
      category
      |> Map.get(:surveys)
      |> Enum.map(fn survey ->
        question_ids = survey_question_ids_per_survey(survey.id)
        Map.put(survey, :survey_question_ids, question_ids)
      end)

    Map.put(category, :surveys, surveys_with_ids)
  end

  defp survey_question_ids_per_survey(survey_id) do
    from(sqs in "survey_question_surveys",
      join: sq in SurveyQuestion,
      on: sq.id == sqs.survey_question_id,
      where: sqs.survey_id == ^survey_id,
      select: sq.id
    )
    |> Repo.all()
  end

  defp add_survey_stats(category, answered_survey_question_ids) do
    surveys_with_stats =
      category
      |> Map.get(:surveys)
      |> Enum.map(fn survey ->
        survey_question_ids = Map.get(survey, :survey_question_ids, [])
        total = length(survey_question_ids)

        answered =
          if total == 0 do
            0
          else
            Enum.count(survey_question_ids, fn id -> id in answered_survey_question_ids end)
          end

        Map.put(survey, :survey_stats, {answered, total})
      end)

    {answered_total, question_total} =
      Enum.reduce(surveys_with_stats, {0, 0}, fn survey, {acc_answered, acc_total} ->
        case Map.get(survey, :survey_stats) do
          {a, t} when is_integer(a) and is_integer(t) -> {acc_answered + a, acc_total + t}
          _ -> {acc_answered, acc_total}
        end
      end)

    percent_complete =
      if question_total == 0 do
        0
      else
        trunc(answered_total / question_total * 100)
      end

    category
    |> Map.put(:surveys, surveys_with_stats)
    |> Map.put(:category_stats, {answered_total, question_total, percent_complete})
  end

  def list_survey_answers do
    Repo.all(from a in SurveyAnswer, order_by: a.display_order)
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
    # Using child_traits instead of non-existent TraitValue module
    # Traits with parent_trait_id are the "values" for traits without parent_trait_id
    traits_query =
      from t in Trait,
        where: is_nil(t.parent_trait_id),
        order_by: t.display_order,
        preload: [child_traits: ^from(ct in Trait, order_by: ct.display_order)]

    surveys_query = from s in Survey, order_by: s.display_order, preload: [traits: ^traits_query]

    query =
      from c in SurveyCategory,
        order_by: c.display_order,
        preload: [surveys: ^surveys_query]

    Repo.all(query)
  end

  def get_survey!(id) do
    # Using child_traits instead of non-existent TraitValue module
    child_traits_query = from ct in Trait, order_by: ct.display_order

    traits_query =
      from t in Trait,
        where: is_nil(t.parent_trait_id),
        order_by: t.display_order,
        preload: [child_traits: ^child_traits_query]

    Repo.get!(Survey, id)
    |> Repo.preload([
      :category,
      traits: traits_query
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
