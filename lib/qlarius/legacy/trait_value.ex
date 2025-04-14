defmodule Qlarius.Legacy.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.{Trait, User}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]
  schema "trait_values" do
    field :value, :string
    field :active, :boolean
    field :display_order, :integer

    belongs_to :trait, Trait
    many_to_many :users, User, join_through: "users_trait_values"

    timestamps()
  end

  def changeset(trait_value, attrs) do
    trait_value
    |> cast(attrs, [:value, :active, :display_order, :trait_id])
    |> validate_required([:value, :trait_id])
    |> foreign_key_constraint(:trait_id)
  end
end
