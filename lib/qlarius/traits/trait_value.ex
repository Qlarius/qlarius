defmodule Qlarius.Traits.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.UserUnused, as: User
  alias Qlarius.Traits.Trait
  alias Qlarius.Traits.UserTag

  schema "trait_values" do
    belongs_to :trait, Trait

    field :name, :string
    field :display_order, :integer
    field :answer, :string

    many_to_many :users, User, join_through: UserTag

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for trait_value.
  """
  def changeset(trait_value, attrs) do
    trait_value
    |> cast(attrs, [:name, :display_order, :trait_id, :answer])
    |> validate_required([:name, :display_order, :trait_id])
  end
end
