defmodule Qlarius.YouData.Surveys.Survey do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.Surveys.SurveyCategory
  alias Qlarius.YouData.Traits.Trait

  schema "surveys" do
    field :name, :string
    field :display_order, :integer, default: 1
    field :active, :boolean, default: false

    belongs_to :category, SurveyCategory, foreign_key: :survey_category_id
    many_to_many :traits, Trait, join_through: "traits_surveys"

    belongs_to :created_by, Qlarius.Accounts.User
    belongs_to :updated_by, Qlarius.Accounts.User

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(survey, attrs) do
    survey
    |> cast(attrs, [:name, :category_id, :display_order, :active])
    |> validate_required([:name])
    |> foreign_key_constraint(:category_id)
  end
end
