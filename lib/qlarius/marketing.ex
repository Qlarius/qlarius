defmodule Qlarius.Marketing do
  @moduledoc """
  The Marketing context.
  """

  @default_marketer_id 88
  @default_media_piece_type_id 1

  import Ecto.Query, warn: false
  require Logger
  alias Qlarius.LegacyRepo

  alias Qlarius.Legacy.{MediaPiece, AdCategory}

  @doc """
  Returns the list of media_pieces.
  """
  def list_media_pieces do
    MediaPiece
    |> order_by([m], asc: m.id)
    |> LegacyRepo.all()
    |> LegacyRepo.preload(:ad_category)
  end

  @doc """
  Gets a single media_piece.
  Raises `Ecto.NoResultsError` if the Media piece does not exist.
  """
  def get_media_piece!(id) do
    MediaPiece
    |> LegacyRepo.get!(id)
    |> LegacyRepo.preload([:ad_category])
  end

  @doc """
  Creates a media_piece.
  """
  def create_media_piece(attrs \\ %{}) do
    Logger.info("Creating media piece with attrs: #{inspect(attrs)}")

    %MediaPiece{}
    |> MediaPiece.changeset(attrs)
    |> LegacyRepo.insert()
    |> case do
      {:ok, media_piece} = result ->
        Logger.info(
          "Successfully created media piece. Banner image: #{inspect(media_piece.banner_image)}"
        )

        result

      {:error, changeset} = error ->
        Logger.error("Failed to create media piece. Errors: #{inspect(changeset.errors)}")
        error
    end
  end

  defp maybe_update_banner_image(result, _image), do: result

  @doc """
  Updates a media_piece.
  """
  def update_media_piece(%MediaPiece{} = media_piece, attrs) do
    Logger.info("Updating media piece #{media_piece.id} with attrs: #{inspect(attrs)}")

    media_piece
    |> MediaPiece.changeset(attrs)
    |> LegacyRepo.update()
    |> case do
      {:ok, media_piece} = result ->
        Logger.info(
          "Successfully updated media piece. Banner image: #{inspect(media_piece.banner_image)}"
        )

        result

      {:error, changeset} = error ->
        Logger.error("Failed to update media piece. Errors: #{inspect(changeset.errors)}")
        error
    end
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
    MediaPiece.update_changeset(media_piece, attrs)
  end

  @doc """
  Returns the list of ad categories for dropdown selection.
  """
  def list_ad_categories do
    LegacyRepo.all(AdCategory)
  end
end
