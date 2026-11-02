defmodule Qlarius.Sponster.Marketing do
  @moduledoc """
  The Marketing context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Qlarius.Repo

  alias Qlarius.Sponster.Ads.{MediaFiles, MediaPiece}

  @doc """
  Returns the list of media_pieces.
  """
  def list_media_pieces do
    MediaPiece
    |> order_by([m], asc: m.id)
    |> Repo.all()
    |> Repo.preload(:ad_category)
  end

  @doc """
  Returns the list of media_pieces for a specific marketer.
  """
  def list_media_pieces_for_marketer(marketer_id) do
    MediaPiece
    |> where([m], m.marketer_id == ^marketer_id)
    |> order_by([m], asc: m.id)
    |> Repo.all()
    |> Repo.preload(:ad_category)
  end

  @doc """
  Gets a single media_piece.
  Raises `Ecto.NoResultsError` if the Media piece does not exist.
  """
  def get_media_piece!(id) do
    MediaPiece
    |> Repo.get!(id)
    |> Repo.preload([:ad_category])
  end

  @doc """
  Creates a media_piece.
  """
  def create_media_piece(attrs \\ %{}) do
    Logger.info("Creating media piece with attrs: #{inspect(attrs)}")

    case store_uploads(attrs) do
      {:ok, attrs} ->
        %MediaPiece{}
        |> MediaPiece.changeset(attrs)
        |> Repo.insert()
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

      {:error, reason} = error ->
        Logger.error("Failed to create media piece. Errors: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Updates a media_piece.
  """
  def update_media_piece(%MediaPiece{} = media_piece, attrs) do
    Logger.info("Updating media piece #{media_piece.id} with attrs: #{inspect(attrs)}")

    case store_uploads(attrs) do
      {:ok, attrs} ->
        media_piece
        |> MediaPiece.changeset(attrs)
        |> Repo.update()
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

      {:error, reason} = error ->
        Logger.error("Failed to update media piece. Errors: #{inspect(reason)}")
        error
    end
  end

  defp store_uploads(attrs) do
    with {:ok, attrs} <- store_field(attrs, "banner_image", :banner) do
      store_field(attrs, "video_file", :video)
    end
  end

  defp store_field(attrs, key, kind) do
    case Map.get(attrs, key) do
      %Plug.Upload{} = upload ->
        try do
          filename = MediaFiles.store!(upload.path, upload.filename, kind)
          {:ok, Map.put(attrs, key, filename)}
        rescue
          error ->
            Logger.error("Failed to upload file: #{inspect(error)}")
            {:error, {:upload_failed, String.to_existing_atom(key), Exception.message(error)}}
        end

      _other ->
        {:ok, attrs}
    end
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
    MediaPiece.changeset(media_piece, attrs)
  end
end
