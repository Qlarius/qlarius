defmodule Qlarius.Arcade.ContentGroupsPieces do
  use Ecto.Schema

  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.ContentPiece

  schema "content_groups_content_pieces" do
    belongs_to :content_group, ContentGroup
    belongs_to :content_piece, ContentPiece
    timestamps(type: :utc_datetime)
  end
end
