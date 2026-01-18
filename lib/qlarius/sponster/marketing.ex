defmodule Qlarius.Sponster.Marketing do
  @moduledoc """
  The Marketing context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Qlarius.Repo

  alias Qlarius.Sponster.Ads.{MediaPiece, AdCategory}

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

    attrs_with_upload = maybe_handle_plug_upload(attrs)

    %MediaPiece{}
    |> MediaPiece.changeset(attrs_with_upload)
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
  end

  @doc """
  Updates a media_piece.
  """
  def update_media_piece(%MediaPiece{} = media_piece, attrs) do
    Logger.info("Updating media piece #{media_piece.id} with attrs: #{inspect(attrs)}")

    attrs_with_upload = maybe_handle_plug_upload(attrs)

    media_piece
    |> MediaPiece.changeset(attrs_with_upload)
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
  end

  defp maybe_handle_plug_upload(%{"banner_image" => %Plug.Upload{} = upload} = attrs) do
    ext = Path.extname(upload.filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    try do
      case storage do
        Waffle.Storage.S3 ->
          upload_to_s3_banner(upload.path, filename)

        _ ->
          upload_to_local_banner(upload.path, filename)
      end

      Map.put(attrs, "banner_image", filename)
    rescue
      error ->
        Logger.error("Failed to upload file: #{inspect(error)}")
        attrs
    end
  end

  defp maybe_handle_plug_upload(%{"video_file" => %Plug.Upload{} = upload} = attrs) do
    ext = Path.extname(upload.filename)
    filename = "#{System.unique_integer([:positive])}#{ext}"

    storage = Application.get_env(:waffle, :storage, Waffle.Storage.Local)

    try do
      case storage do
        Waffle.Storage.S3 ->
          upload_to_s3_video(upload.path, filename)

        _ ->
          upload_to_local_video(upload.path, filename)
      end

      Map.put(attrs, "video_file", filename)
    rescue
      error ->
        Logger.error("Failed to upload video file: #{inspect(error)}")
        attrs
    end
  end

  defp maybe_handle_plug_upload(attrs), do: attrs

  defp upload_to_local_banner(source_path, filename) do
    dest_dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "banners",
        "three_tap_banners"
      ])

    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.cp!(source_path, dest_path)
  end

  defp upload_to_s3_banner(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)
    s3_path = "uploads/media_pieces/banners/three_tap_banners/#{filename}"
    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
  end

  defp upload_to_local_video(source_path, filename) do
    dest_dir =
      Path.join([
        :code.priv_dir(:qlarius),
        "static",
        "uploads",
        "media_pieces",
        "videos"
      ])

    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)
    File.cp!(source_path, dest_path)
  end

  defp upload_to_s3_video(source_path, filename) do
    bucket = Application.get_env(:waffle, :bucket)
    s3_path = "uploads/media_pieces/videos/#{filename}"
    {:ok, file_binary} = File.read(source_path)

    ExAws.S3.put_object(bucket, s3_path, file_binary)
    |> ExAws.request!()
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

  @doc """
  Returns the list of ad categories for dropdown selection.
  """
  def list_ad_categories do
    Repo.all(AdCategory)
  end
end
