defmodule Qlarius.YouData.Surveys.SurveyQuestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.Survey
  alias Qlarius.YouData.Traits.Trait

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]

  schema "survey_questions" do
    field :text, :string
    field :active, :binary
    field :display_order, :integer
    field :added_by, :integer
    field :modified_by, :integer

    belongs_to :trait, Trait
    many_to_many :surveys, Survey, join_through: "survey_question_surveys"

    timestamps()
  end

  def changeset(survey_question, attrs) do
    survey_question
    |> cast(attrs, [
      :text,
      :trait_id,
      :active,
      :display_order,
      :added_by,
      :modified_by
    ])
    |> validate_length(:text, max: 4096)
    |> foreign_key_constraint(:trait_id)
  end

  # Helper function to convert binary active field to boolean
  #TODO: Remove this once we have a proper boolean field
  def active?(survey_question) do
    case survey_question.active do
      "1" -> true
      "0" -> false
      <<49>> -> true  # binary "1"
      <<48>> -> false # binary "0"
      _ -> false
    end
  end
end
