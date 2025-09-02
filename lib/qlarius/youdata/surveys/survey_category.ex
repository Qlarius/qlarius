defmodule Qlarius.YouData.Surveys.SurveyCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :added_date, updated_at: :modified_date]

  schema "survey_categories" do
    field :survey_category_name, :string
    field :display_order, :integer

    has_many :surveys, Qlarius.YouData.Surveys.Survey

    timestamps()
  end

  def changeset(survey_category, attrs) do
    survey_category
    |> cast(attrs, [
      :survey_category_name,
      :display_order,
      :added_by,
      :modified_by
    ])
    |> validate_required([:survey_category_name])
    |> validate_length(:survey_category_name, max: 256)
  end
end
