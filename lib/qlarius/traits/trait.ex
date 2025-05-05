defmodule Qlarius.Traits.Trait do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "traits" do
    field :name, :string, source: :trait_name
    field :active, :boolean
    field :is_taggable, :boolean
    field :input_type, :string
    field :display_order, :integer

    field :parent_trait_id, :integer

    field :is_campaign_only, :boolean, default: false
    field :is_numeric, :boolean, default: true
    belongs_to :updated_by, Qlarius.Accounts.User, foreign_key: :modified_by
    belongs_to :inserted_by, Qlarius.Accounts.User, foreign_key: :added_by
    field :immutable, :boolean, default: false
    field :max_length, :integer
    field :max_selected, :integer
    field :is_date, :boolean, default: false

    belongs_to :trait_category, Qlarius.Traits.TraitCategory

    # has_many :values, Qlarius.Traits.TraitValue

    # many_to_many :surveys, Qlarius.Surveys.Survey, join_through: "traits_surveys"
    # many_to_many :trait_groups, Qlarius.Campaigns.TraitGroup, join_through: "traits_trait_groups"

    timestamps(
      type: :utc_datetime,
      inserted_at_source: :added_date,
      updated_at_source: :modified_date
    )
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
