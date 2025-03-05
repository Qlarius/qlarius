defmodule Qlarius.Traits.TraitCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Traits.Trait

  schema "trait_categories" do
    field :name, :string
    field :display_order, :integer

    has_many :traits, Trait, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end
end
