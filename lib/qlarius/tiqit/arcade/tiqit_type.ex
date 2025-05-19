defmodule Qlarius.Tiqit.Arcade.TiqitType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiqit_types" do
    field :name, :string
    # if duration_hours is null then tiqit doesn't expire
    field :duration_hours, :integer
    field :price, :decimal
    field :active, :boolean, default: true

    belongs_to :content_piece, Qlarius.Tiqit.Arcade.ContentPiece
    has_many :tiqits, Qlarius.Tiqit.Arcade.Tiqit

    timestamps()
  end

  def changeset(tiqit_type, attrs) do
    tiqit_type
    |> cast(attrs, [:content_piece_id, :name, :duration_hours, :price, :active])
    |> validate_required([:content_piece_id, :name, :duration_hours, :price, :active])
    |> validate_length(:name, max: 50)
    |> assoc_constraint(:content_piece)
  end
end
