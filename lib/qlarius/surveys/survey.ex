defmodule Qlarius.Surveys.Survey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "surveys" do
    field :name, :string
    field :display_order, :integer
    field :active, :boolean, default: false

    belongs_to :category, SurveyCategory
    many_to_many :questions, SurveyQuestion, join_through: "survey_question_surveys"

    timestamps()
  end

  def changeset(survey, attrs) do
    survey
    |> cast(attrs, [:name, :category_id, :display_order, :active])
    |> validate_required([:name])
    |> foreign_key_constraint(:category_id)
  end
end
