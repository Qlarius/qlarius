defmodule Qlarius.YouData.Surveys.SurveyCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.Survey

  schema "survey_categories" do
    field :name, :string
    field :display_order, :integer

    has_many :surveys, Survey, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  def changeset(survey_category, attrs) do
    survey_category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name])
  end
end
