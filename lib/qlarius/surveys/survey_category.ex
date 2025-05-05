defmodule Qlarius.Surveys.SurveyCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Surveys.Survey

  schema "survey_categories" do
    field :name, :string, source: :survey_category_name
    field :display_order, :integer

    has_many :surveys, Survey, foreign_key: :category_id

    belongs_to :added_by, Qlarius.Accounts.User
    belongs_to :modified_by, Qlarius.Accounts.User

    timestamps(
      type: :utc_datetime,
      inserted_at_source: :created_at,
      updated_at_source: :modified_date
    )
  end

  def changeset(survey_category, attrs) do
    survey_category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name])
  end
end
