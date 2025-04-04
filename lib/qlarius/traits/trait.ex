defmodule Qlarius.Traits.Trait do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Campaigns.TraitGroup
  alias Qlarius.Surveys.Survey
  alias Qlarius.Traits.TraitCategory
  alias Qlarius.Traits.TraitValue

  schema "traits" do
    field :name, :string
    field :campaign_only, :boolean
    field :numeric, :boolean
    field :immutable, :boolean
    field :taggable, :boolean
    field :is_date, :boolean
    field :active, :boolean
    field :display_order, :integer, default: 1
    field :input_type, Ecto.Enum, values: ~w[radios checkboxes text select]a
    field :question, :string

    belongs_to :category, TraitCategory

    has_many :values, TraitValue

    many_to_many :surveys, Survey, join_through: "traits_surveys"
    many_to_many :trait_groups, TraitGroup, join_through: "traits_trait_groups"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for trait.
  """
  def changeset(trait, attrs) do
    trait
    |> cast(attrs, [
      :name,
      :input_type,
      :category_id,
      :campaign_only,
      :numeric,
      :immutable,
      :taggable,
      :is_date,
      :active,
      :question
    ])
    |> validate_required([:name, :input_type, :category_id])
  end
end
