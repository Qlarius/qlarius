defmodule Qlarius.Sponster.Campaigns.TraitGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.TargetBand
  alias Qlarius.YouData.Traits.Trait

  schema "trait_groups" do
    field :description, :string
    field :title, :string

    belongs_to :trait, Qlarius.YouData.Traits.TraitValue, foreign_key: :parent_trait_id

    belongs_to :created_by, Qlarius.Accounts.User, foreign_key: :user_created_by
    field :deactivated_at, :utc_datetime

    many_to_many :target_bands, TargetBand, join_through: "target_bands_trait_groups"
    many_to_many :traits, Trait, join_through: "trait_group_traits"

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(trait_group, attrs) do
    trait_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
    |> put_assoc(:traits, Map.get(attrs, :traits, []))
  end
end
