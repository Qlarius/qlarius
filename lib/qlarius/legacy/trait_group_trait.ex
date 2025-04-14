defmodule Qlarius.Legacy.TraitGroupTrait do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.{Trait, TraitGroup}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "trait_group_traits" do
    belongs_to :trait_group, TraitGroup
    belongs_to :trait, Trait

    timestamps()
  end

  def changeset(trait_group_trait, attrs) do
    trait_group_trait
    |> cast(attrs, [:trait_group_id, :trait_id])
    |> validate_required([:trait_group_id, :trait_id])
    |> foreign_key_constraint(:trait_group_id)
    |> foreign_key_constraint(:trait_id)
  end
end
