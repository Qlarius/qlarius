defmodule Qlarius.YouData.Traits.TraitCategory do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.YouData.Traits.Trait

  schema "trait_categories" do
    field :name, :string, source: :trait_category_name
    field :display_order, :integer

    belongs_to :updated_by, Qlarius.Accounts.User, foreign_key: :modified_by
    belongs_to :inserted_by, Qlarius.Accounts.User, foreign_key: :added_by

    has_many :traits, Trait

    timestamps(
      type: :utc_datetime,
      inserted_at_source: :added_date,
      updated_at_source: :modified_date
    )
  end

  def changeset(trait_category, attrs) do
    trait_category
    |> cast(attrs, [:name, :display_order])
    |> validate_required([:name, :display_order])
    |> unique_constraint(:name)
  end
end
