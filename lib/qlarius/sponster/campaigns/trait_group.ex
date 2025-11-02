defmodule Qlarius.Sponster.Campaigns.TraitGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{TraitGroupTrait, TargetBandTraitGroup}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "trait_groups" do
    field :title, :string
    field :description, :string
    field :parent_trait_id, :integer
    field :marketer_id, :integer
    field :user_created_by, :integer
    field :deactivated_at, :naive_datetime

    has_many :trait_group_traits, TraitGroupTrait
    has_many :traits, through: [:trait_group_traits, :trait]

    has_many :target_band_trait_groups, TargetBandTraitGroup
    has_many :target_bands, through: [:target_band_trait_groups, :target_band]

    timestamps()
  end

  def changeset(trait_group, attrs) do
    trait_group
    |> cast(attrs, [
      :title,
      :description,
      :parent_trait_id,
      :marketer_id,
      :user_created_by,
      :deactivated_at
    ])
    |> validate_required([:title, :marketer_id])
  end
end
