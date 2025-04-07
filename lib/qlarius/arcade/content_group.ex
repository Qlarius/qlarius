defmodule Qlarius.Arcade.ContentGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_groups" do
    field :type, :string
    field :description, :string
    field :title, :string

    many_to_many :content_pieces, ContentPiece, join_through: "content_groups_content_pieces"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description, :type])
    |> validate_required([:title, :description, :type])
  end
end
