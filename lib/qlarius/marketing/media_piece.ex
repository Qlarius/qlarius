defmodule Qlarius.Marketing.MediaPiece do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_pieces" do
    field :title, :string
    field :body_copy, :string
    field :display_url, :string
    field :jump_url, :string
    field :ad_category_id, :integer

    timestamps()
  end

  @doc false
  def changeset(media_piece, attrs) do
    media_piece
    |> cast(attrs, [:title, :body_copy, :display_url, :jump_url, :ad_category_id])
    |> validate_required([:title, :body_copy, :display_url, :jump_url, :ad_category_id])
    |> validate_format(:display_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
    |> validate_format(:jump_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
  end
end
