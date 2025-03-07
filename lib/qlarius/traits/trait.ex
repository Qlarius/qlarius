defmodule Qlarius.Traits.Trait do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.User
  alias Qlarius.Campaigns.TraitGroup
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
    field :input_type, :string

    belongs_to :category, TraitCategory

    has_many :values, TraitValue

    many_to_many :users, User, join_through: "user_traits"
    many_to_many :trait_groups, TraitGroup, join_through: "traits_trait_groups"

    timestamps(type: :utc_datetime)
  end
end
