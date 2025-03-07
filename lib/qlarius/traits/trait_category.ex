defmodule Qlarius.Traits.TraitCategory do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Traits.Trait

  schema "trait_categories" do
    field :name, :string
    field :display_order, :integer

    has_many :traits, Trait, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for trait_category.
  """
  def changeset(trait_category, attrs) do
    trait_category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name, :display_order])
  end
end
