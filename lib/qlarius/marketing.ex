defmodule Qlarius.Marketing do
  @moduledoc """
  The Marketing context.
  """

  import Ecto.Query, warn: false
  alias Qlarius.LegacyRepo

  alias Qlarius.Legacy.{MediaPiece, AdCategory}


  @doc """
  Returns the list of media_pieces.
  """
  def list_media_pieces do
    LegacyRepo.all(MediaPiece) |> LegacyRepo.preload(:ad_category)
  end

  @doc """
  Gets a single media_piece.
  Raises `Ecto.NoResultsError` if the Media piece does not exist.
  """
  def get_media_piece!(id), do: LegacyRepo.get!(MediaPiece, id)

  @doc """
  Creates a media_piece.
  """
  def create_media_piece(attrs \\ %{}) do
    %MediaPiece{}
    |> MediaPiece.changeset(attrs)
    |> LegacyRepo.insert()
  end

  @doc """
  Updates a media_piece.
  """
  def update_media_piece(%MediaPiece{} = media_piece, attrs) do
    media_piece
    |> MediaPiece.changeset(attrs)
    |> LegacyRepo.update()
  end

  @doc """
  Deletes a media_piece.
  """
  def delete_media_piece(%MediaPiece{} = media_piece) do
    LegacyRepo.delete(media_piece)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_piece changes.
  """
  def change_media_piece(%MediaPiece{} = media_piece, attrs \\ %{}) do
    MediaPiece.changeset(media_piece, attrs)
  end

  @doc """
  Returns the list of ad categories for dropdown selection.
  """
  def list_ad_categories do
    LegacyRepo.all(AdCategory)
  end
end
