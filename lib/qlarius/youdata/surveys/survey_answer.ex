defmodule Qlarius.YouData.Surveys.SurveyAnswer do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.SurveyQuestion
  alias Qlarius.YouData.Traits.Trait

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]

  schema "survey_answers" do
    field :text, :string
    field :display_order, :integer
    field :added_by, :integer
    field :modified_by, :integer

    belongs_to :survey_question, SurveyQuestion
    belongs_to :trait, Trait
    belongs_to :next_survey_question, SurveyQuestion

    timestamps()
  end

  def changeset(survey_answer, attrs) do
    survey_answer
    |> cast(attrs, [
      :text,
      :survey_question_id,
      :trait_id,
      :display_order,
      :added_by,
      :modified_by
    ])
    |> validate_length(:text, max: 4096)
    |> foreign_key_constraint(:survey_question_id)
    |> foreign_key_constraint(:trait_id)
  end
end
