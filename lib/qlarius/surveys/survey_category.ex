defmodule Qlarius.Surveys.SurveyCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Surveys.Survey

  schema "survey_categories" do
    field :name, :string
    field :display_order, :integer

    has_many :surveys, Survey

    timestamps(type: :utc_datetime)
  end

  def changeset(survey_category, attrs) do
    survey_category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name])
  end
end
