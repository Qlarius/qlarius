defmodule Qlarius.YouData.Surveys.SurveyCategories do
  import Ecto.Query, warn: false
  alias Qlarius.Repo
  alias Qlarius.YouData.Surveys.SurveyCategory

  def list_survey_categories(_scope) do
    from(sc in SurveyCategory,
      left_join: s in assoc(sc, :surveys),
      on: s.active == true,
      group_by: sc.id,
      order_by: [asc: sc.display_order, asc: sc.survey_category_name],
      select: %{
        sc
        | surveys: fragment("count(CASE WHEN ? = true THEN ? END)", s.active, s.id)
      }
    )
    |> Repo.all()
    |> Enum.map(fn category ->
      Map.put(category, :active_survey_count, category.surveys)
    end)
  end

  def get_survey_category!(_scope, id) do
    Repo.get!(SurveyCategory, id)
  end

  def create_survey_category(_scope, attrs) do
    %SurveyCategory{}
    |> SurveyCategory.changeset(attrs)
    |> Repo.insert()
  end

  def update_survey_category(_scope, %SurveyCategory{} = category, attrs) do
    category
    |> SurveyCategory.changeset(attrs)
    |> Repo.update()
  end

  def delete_survey_category(_scope, %SurveyCategory{} = category) do
    if can_delete?(category) do
      Repo.delete(category)
    else
      {:error, :has_surveys}
    end
  end

  def change_survey_category(_scope, %SurveyCategory{} = category, attrs \\ %{}) do
    SurveyCategory.changeset(category, attrs)
  end

  def can_delete?(%SurveyCategory{} = category) do
    survey_count =
      from(s in Qlarius.YouData.Surveys.Survey,
        where: s.survey_category_id == ^category.id,
        select: count(s.id)
      )
      |> Repo.one()

    survey_count == 0
  end
end
