defmodule Qlarius.MediaPiece do
  use Ecto.Schema

  schema "media_pieces" do
    field :title, :string
    field :display_url, :string
    field :body_copy, :string

    timestamps()
  end
end
