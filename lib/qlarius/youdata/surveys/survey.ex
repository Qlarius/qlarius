defmodule Qlarius.YouData.Surveys.Survey do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.{SurveyCategory, SurveyQuestion}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "surveys" do
    field :name, :string
    field :display_order, :integer
    field :active, :boolean, default: false
    field :created_by, :integer
    field :updated_by, :integer

    belongs_to :survey_category, SurveyCategory
    many_to_many :survey_questions, SurveyQuestion, join_through: "survey_question_surveys"

    timestamps()
  end

  def changeset(survey, attrs) do
    survey
    |> cast(attrs, [
      :name,
      :survey_category_id,
      :display_order,
      :active,
      :created_by,
      :updated_by
    ])
    |> validate_required([:name])
    |> validate_length(:name, max: 512)
    |> foreign_key_constraint(:survey_category_id)
  end
end
