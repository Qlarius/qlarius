defmodule Qlarius.Tiqit.Arcade.ContentGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.ContentPiece

  schema "content_groups" do
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
