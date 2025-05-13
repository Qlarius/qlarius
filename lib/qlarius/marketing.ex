defmodule Qlarius.Marketing do
  @moduledoc """
  The Marketing context.
  """

  @default_marketer_id 88
  @default_media_piece_type_id 1

  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Marketing.MediaPiece
  alias Qlarius.Campaigns.AdCategory

  @doc """
  Returns the list of media_pieces.
  """
  def list_media_pieces do
    Repo.all(from mp in MediaPiece, order_by: [asc: mp.id], preload: :ad_category)
  end

  @doc """
  Gets a single media_piece.
  Raises `Ecto.NoResultsError` if the Media piece does not exist.
  """
  def get_media_piece!(id), do: Repo.get!(MediaPiece, id)

  @doc """
  Creates a media_piece.
  """
  def create_media_piece(attrs \\ %{}) do
    %MediaPiece{
      active: true,
      marketer_id: @default_marketer_id,
      media_piece_type_id: @default_media_piece_type_id
    }
    |> MediaPiece.create_changeset(attrs)
    |> Repo.insert()
    |> maybe_update_banner_image(attrs["banner_image"])
  end

  defp maybe_update_banner_image({:ok, piece}, image) when not is_nil(image) do
    update_media_piece(piece, %{banner_image: image})
  end

  defp maybe_update_banner_image(result, _image), do: result

  @doc """
  Updates a media_piece.
  """
  def update_media_piece(%MediaPiece{} = media_piece, attrs) do
    media_piece
    |> MediaPiece.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_piece.
  """
  def delete_media_piece(%MediaPiece{} = media_piece) do
    Repo.delete(media_piece)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_piece changes.
  """
  def change_media_piece(%MediaPiece{} = media_piece, attrs \\ %{}) do
    MediaPiece.update_changeset(media_piece, attrs)
  end

  @doc """
  Returns the list of ad categories for dropdown selection.
  """
  def list_ad_categories do
    Repo.all(AdCategory)
  end
end
