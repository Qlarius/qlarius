defmodule Qlarius.Traits.TraitValue do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Traits.Trait

  schema "trait_values" do
    belongs_to :trait, Trait

    field :name, :string
    field :display_order, :integer

    timestamps(type: :utc_datetime)
  end
end
