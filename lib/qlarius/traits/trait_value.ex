defmodule Qlarius.Traits.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Traits.Trait

  schema "trait_values" do
    belongs_to :trait, Trait

    field :name, :string
    field :display_order, :integer
    field :answer, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for trait_value.
  """
  def changeset(trait_value, attrs) do
    trait_value
    |> cast(attrs, [:name, :display_order, :trait_id])
    |> validate_required([:name, :display_order, :trait_id])
  end
end
