defmodule Qlarius.Surveys.SurveyQuestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Traits.Trait
  alias Qlarius.Surveys.Survey
  alias Qlarius.Surveys.SurveyAnswer

  schema "survey_questions" do
    field :text, :string
    field :active, :boolean, default: false
    field :display_order, :integer, default: 1

    belongs_to :trait, Trait
    many_to_many :surveys, Survey, join_through: "survey_question_surveys"
    has_many :answers, SurveyAnswer
    has_many :next_questions, SurveyAnswer, foreign_key: :next_question_id

    timestamps(type: :utc_datetime)
  end

  def changeset(survey_question, attrs) do
    survey_question
    |> cast(attrs, [:text, :trait_id, :active, :display_order])
    |> validate_required([:text])
    |> foreign_key_constraint(:trait_id)
  end
end
