defmodule Qlarius.Sponster.Campaigns.TargetBandTraitGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{TargetBand, TraitGroup}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "target_band_trait_groups" do
    belongs_to :target_band, TargetBand
    belongs_to :trait_group, TraitGroup

    timestamps()
  end

  def changeset(target_band_trait_group, attrs) do
    target_band_trait_group
    |> cast(attrs, [:target_band_id, :trait_group_id])
    |> validate_required([:target_band_id, :trait_group_id])
    |> foreign_key_constraint(:target_band_id)
    |> foreign_key_constraint(:trait_group_id)
  end
end
