defmodule Qlarius.YouData.Surveys.SurveyAnswer do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.SurveyQuestion
  alias Qlarius.YouData.Traits.Trait

  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]
  schema "survey_answers" do
    field :text, :string
    field :display_order, :integer
    field :modified_by, :integer
    field :added_by, :integer

    belongs_to :survey_question, SurveyQuestion
    belongs_to :trait, Trait

    timestamps()
  end

  def changeset(survey_answer, attrs) do
    survey_answer
    |> cast(attrs, [:text, :survey_question_id, :trait_id, :display_order, :modified_by, :added_by])
    |> validate_required([:text, :survey_question_id, :display_order, :modified_by, :added_by])
    |> foreign_key_constraint(:survey_question_id)
    |> foreign_key_constraint(:next_survey_question_id)
    |> foreign_key_constraint(:trait_id)
  end
end
