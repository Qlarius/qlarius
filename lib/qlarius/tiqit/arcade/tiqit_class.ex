defmodule Qlarius.Tiqit.Arcade.TiqitClass do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqit_classes" do
    field :price, :decimal
    field :active, :boolean, default: true

    # nil duration = lifetime access
    field :duration_hours, :integer

    belongs_to :catalog, Qlarius.Tiqit.Arcade.Catalog
    belongs_to :content_group, Qlarius.Tiqit.Arcade.ContentGroup
    belongs_to :content_piece, Qlarius.Tiqit.Arcade.ContentPiece

    timestamps()
  end

  def changeset(tc, params) do
    tc
    |> cast(params, ~w[duration_hours price]a)
    |> validate_required([:price])
    |> validate_number(:duration_hours, greater_than: 0)
    |> unsafe_validate_unique([:duration_hours, :catalog_id], Qlarius.Repo)
    |> unique_constraint([:duration_hours, :catalog_id])
    |> unsafe_validate_unique([:duration_hours, :content_group_id], Qlarius.Repo)
    |> unique_constraint([:duration_hours, :content_group_id])
    |> unsafe_validate_unique([:duration_hours, :content_piece_id], Qlarius.Repo)
    |> unique_constraint([:duration_hours, :content_piece_id])
    |> validate_number(:price, greater_than: 0)
  end
end
