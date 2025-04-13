defmodule Qlarius.Legacy.TraitGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.{Trait, TraitGroupTrait}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "trait_groups" do
    field :name, :string
    field :description, :string
    field :active, :boolean
    field :display_order, :integer
    field :marketer_id, :integer
    field :deactivated_at, :naive_datetime

    has_many :trait_group_traits, TraitGroupTrait
    has_many :traits, through: [:trait_group_traits, :trait]

    timestamps()
  end

  def changeset(trait_group, attrs) do
    trait_group
    |> cast(attrs, [:name, :description, :active, :display_order, :marketer_id, :deactivated_at])
    |> validate_required([:name, :active, :marketer_id])
  end
end
