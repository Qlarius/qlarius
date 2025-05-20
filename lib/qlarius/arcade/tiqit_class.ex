defmodule Qlarius.Arcade.TiqitClass do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqit_classes" do
    field :price, :decimal
    field :active, :boolean, default: true
    field :duration_hours, :integer

    belongs_to :catalog, Qlarius.Arcade.Catalog
    belongs_to :content_group, Qlarius.Arcade.ContentGroup
    belongs_to :content_piece, Qlarius.Arcade.ContentPiece

    timestamps()
  end

  def changeset(tc, params) do
    tc
    |> cast(params, ~w[duration_hours price]a)
    |> validate_required([:price])
    |> validate_number(:duration_hours, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
  end
end
