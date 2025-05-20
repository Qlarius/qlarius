defmodule Qlarius.Tiqit.Arcade.TiqitClass do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqit_classes" do
    field :name, :string
    field :price, :decimal
    field :active, :boolean, default: true
    field :duration_hours, :integer

    belongs_to :catalog, Qlarius.Tiqit.Arcade.Catalog
    belongs_to :content_group, Qlarius.Tiqit.Arcade.ContentGroup
    belongs_to :content_piece, Qlarius.Tiqit.Arcade.ContentPiece

    timestamps()
  end

  def changeset(tc, params) do
    tc
    |> cast(params, ~w[name duration_hours price]a)
    |> validate_required([:name, :price])
    |> validate_number(:duration_hours, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
  end
end
