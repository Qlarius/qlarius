defmodule Qlarius.Campaigns.TraitGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Campaigns.TargetBand
  alias Qlarius.Traits.Trait

  schema "trait_groups" do
    field :description, :string
    field :title, :string

    many_to_many :target_bands, TargetBand, join_through: "target_bands_trait_groups"
    many_to_many :traits, Trait, join_through: "traits_trait_groups"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trait_group, attrs) do
    trait_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
    |> put_assoc(:traits, Map.get(attrs, :traits, []))
  end
end
