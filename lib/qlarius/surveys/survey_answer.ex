defmodule Qlarius.Surveys.SurveyAnswer do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Surveys.SurveyQuestion
  alias Qlarius.Traits.Trait
  alias Qlarius.Surveys.SurveyQuestion

  schema "survey_answers" do
    field :text, :string
    field :display_order, :integer

    belongs_to :question, SurveyQuestion
    belongs_to :trait, Trait
    belongs_to :next_question, SurveyQuestion

    timestamps()
  end

  def changeset(survey_answer, attrs) do
    survey_answer
    |> cast(attrs, [
      :text,
      :survey_question_id,
      :trait_id,
      :display_order,
      :next_survey_question_id
    ])
    |> validate_required([:text, :survey_question_id])
    |> foreign_key_constraint(:survey_question_id)
    |> foreign_key_constraint(:trait_id)
    |> foreign_key_constraint(:next_survey_question_id)
  end
end
