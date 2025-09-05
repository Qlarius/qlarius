defmodule Qlarius.YouData.Surveys.SurveyQuestionSurvey do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.{Survey, SurveyQuestion}

  @primary_key {:id, :id, autogenerate: true}

  schema "survey_question_surveys" do
    field :display_order, :integer

    belongs_to :survey_question, SurveyQuestion
    belongs_to :survey, Survey

    timestamps()
  end

  def changeset(survey_question_survey, attrs) do
    survey_question_survey
    |> cast(attrs, [
      :survey_question_id,
      :survey_id,
      :display_order
    ])
    |> validate_required([:survey_question_id, :survey_id])
    |> foreign_key_constraint(:survey_question_id)
    |> foreign_key_constraint(:survey_id)
    |> unique_constraint([:survey_question_id, :survey_id],
      name: "survey_question_surveys_survey_question_id_survey_id_index"
    )
  end
end
