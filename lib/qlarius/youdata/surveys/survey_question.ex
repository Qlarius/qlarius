defmodule Qlarius.YouData.Surveys.SurveyQuestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.SurveyAnswer

  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]
  schema "survey_questions" do
    field :trait_id, :integer
    field :text, :string
    field :modified_by, :integer
    field :added_by, :integer

    has_many :answers, SurveyAnswer

    timestamps()
  end

  def changeset(survey_question, attrs) do
    survey_question
    |> cast(attrs, [:text, :survey_id, :display_order, :modified_by, :added_by, :trait_id])
    |> validate_required([:text, :survey_id, :display_order, :modified_by, :added_by, :trait_id])
    |> foreign_key_constraint(:survey_id)
  end
end
