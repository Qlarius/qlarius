defmodule Qlarius.Surveys do
  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Surveys.SurveyCategory
  alias Qlarius.Surveys.Survey

  # Survey Category functions

  def list_survey_categories do
    Repo.all(from c in SurveyCategory, order_by: c.display_order)
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
