defmodule Qlarius.Sponster.Ads.MediaFiles do
  @moduledoc """
  Stores a media-piece file under a descriptive, unused name.

  The name comes from the original file name. A name already stored on any
  media piece, or already present at the destination, gets a numeric suffix.
  Existing stored names are left as they are.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.MediaPiece

  @max_attempts 20

  @doc """
  URL-safe file name keeping the original words and extension.

  `"Brand Slug_alt1.PNG"` becomes `"brand-slug_alt1.png"`.
  """
  def descriptive_name(original) do
    leaf =
      original
      |> to_string()
      |> String.trim()
      |> String.replace("\\", "/")
      |> Path.basename()

    ext = leaf |> Path.extname() |> String.downcase() |> safe_extension()

    base =
      leaf
      |> Path.basename(Path.extname(leaf))
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_-]+/u, "-")
      |> String.replace(~r/-+/, "-")
      |> String.replace(~r/^[-_]+|[-_]+$/, "")

    base = if base == "", do: "file", else: String.slice(base, 0, 80)
    base <> ext
  end

  @doc """
  Stores the file and returns the filename that was written.

  `kind` is `:banner`, `:video`, or `:poster`.
  """
  def store!(source_path, original_filename, kind) when kind in [:banner, :video, :poster] do
    body = File.read!(source_path)
    write_attempt!(body, descriptive_name(original_filename), kind, 1)
  end

  @doc """
  Media pieces that share one stored file name, across banner, video, and poster.
  """
  def shared_filenames do
    MediaPiece
    |> Repo.all()
    |> Enum.flat_map(&file_rows/1)
    |> Enum.group_by(& &1.filename)
    |> Enum.filter(fn {_filename, rows} -> length(rows) > 1 end)
    |> Enum.map(fn {filename, rows} ->
      %{filename: filename, pieces: Enum.sort_by(rows, & &1.id)}
    end)
    |> Enum.sort_by(& &1.filename)
  end

  @doc """
  Reads an object's last-modified time. Does not write.
  """
  def object_head(s3_key) when is_binary(s3_key) do
    case ExAws.S3.head_object(bucket!(), s3_key) |> ExAws.request() do
      {:ok, %{headers: headers}} ->
        {:ok, %{last_modified: last_modified(headers)}}

      {:error, {:http_error, 404, _}} ->
        {:missing, nil}

      {:error, {type, _}} when type in ["NotFound", "NoSuchKey"] ->
        {:missing, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def s3_key(:banner_image, filename), do: s3_key(:banner, filename)
  def s3_key(:video_file, filename), do: s3_key(:video, filename)
  def s3_key(:video_poster_image, filename), do: s3_key(:poster, filename)
  def s3_key(:banner, filename), do: "uploads/media_pieces/banners/three_tap_banners/#{filename}"
  def s3_key(:video, filename), do: "uploads/media_pieces/videos/#{filename}"
  def s3_key(:poster, filename), do: "uploads/media_pieces/videos/posters/#{filename}"

  defp write_attempt!(_body, name, _kind, attempt) when attempt > @max_attempts do
    raise "No free media file name for #{name} after #{@max_attempts} tries"
  end

  defp write_attempt!(body, name, kind, attempt) do
    filename = candidate(name, attempt)

    if taken?(filename, kind) do
      write_attempt!(body, name, kind, attempt + 1)
    else
      case write!(kind, filename, body) do
        :ok -> filename
        :taken -> write_attempt!(body, name, kind, attempt + 1)
      end
    end
  end

  defp candidate(name, 1), do: name

  defp candidate(name, n) do
    ext = Path.extname(name)
    root = Path.rootname(name)
    "#{root}_#{n}#{ext}"
  end

  defp taken?(filename, kind) do
    db_taken?(filename) or object_taken?(filename, kind)
  end

  defp db_taken?(filename) do
    Repo.exists?(
      from m in MediaPiece,
        where:
          m.banner_image == ^filename or m.video_file == ^filename or
            m.video_poster_image == ^filename
    )
  end

  defp object_taken?(filename, kind) do
    if s3_storage?() do
      s3_exists?(s3_key(kind, filename))
    else
      File.exists?(local_path(kind, filename))
    end
  end

  defp write!(kind, filename, body) do
    if s3_storage?() do
      write_s3!(s3_key(kind, filename), body)
    else
      write_local!(local_path(kind, filename), body)
    end
  end

  defp write_local!(path, body) do
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:write, :exclusive, :binary]) do
      {:ok, io} ->
        try do
          IO.binwrite(io, body)
        after
          File.close(io)
        end

        :ok

      {:error, :eexist} ->
        :taken

      {:error, reason} ->
        raise "Could not store media file: #{inspect(reason)}"
    end
  end

  defp write_s3!(key, body) do
    result =
      ExAws.S3.put_object(bucket!(), key, body, if_none_match: "*")
      |> ExAws.request()

    case result do
      {:ok, _} ->
        :ok

      {:error, {:http_error, status, _}} when status in [409, 412] ->
        :taken

      {:error, {type, _}} when type in ["PreconditionFailed", "ConditionalRequestConflict"] ->
        :taken

      {:error, reason} ->
        raise "Could not store media file: #{inspect(reason)}"
    end
  end

  defp s3_exists?(key) do
    case ExAws.S3.head_object(bucket!(), key) |> ExAws.request() do
      {:ok, _} -> true
      {:error, {:http_error, 404, _}} -> false
      {:error, {type, _}} when type in ["NotFound", "NoSuchKey"] -> false
      {:error, reason} -> raise "Could not check media file: #{inspect(reason)}"
    end
  end

  defp file_rows(piece) do
    [:banner_image, :video_file, :video_poster_image]
    |> Enum.flat_map(fn field ->
      case Map.get(piece, field) do
        name when is_binary(name) and name != "" ->
          [
            %{
              id: piece.id,
              title: piece.title,
              field: field,
              filename: name,
              updated_at: piece.updated_at,
              s3_key: s3_key(field, name)
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp local_path(kind, filename) do
    Path.join(local_dir(kind), filename)
  end

  defp local_dir(:banner) do
    Path.join([
      :code.priv_dir(:qlarius),
      "static",
      "uploads",
      "media_pieces",
      "banners",
      "three_tap_banners"
    ])
  end

  defp local_dir(:video) do
    Path.join([:code.priv_dir(:qlarius), "static", "uploads", "media_pieces", "videos"])
  end

  defp local_dir(:poster) do
    Path.join([
      :code.priv_dir(:qlarius),
      "static",
      "uploads",
      "media_pieces",
      "videos",
      "posters"
    ])
  end

  defp safe_extension("." <> rest) do
    clean = String.replace(rest, ~r/[^a-z0-9]+/, "")
    if clean == "", do: "", else: "." <> clean
  end

  defp safe_extension(_), do: ""

  defp s3_storage? do
    Application.get_env(:waffle, :storage, Waffle.Storage.Local) == Waffle.Storage.S3
  end

  defp bucket! do
    Application.get_env(:waffle, :bucket) || raise "Waffle S3 bucket is not configured"
  end

  defp last_modified(headers) do
    case header_value(headers, "last-modified") do
      nil ->
        nil

      value ->
        case :httpd_util.convert_request_date(String.to_charlist(value)) do
          {{year, month, day}, {hour, minute, second}} ->
            NaiveDateTime.new!(year, month, day, hour, minute, second)

          _ ->
            nil
        end
    end
  end

  defp header_value(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: to_string(value)

      _ ->
        nil
    end)
  end

  defp header_value(headers, name) when is_map(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: to_string(value)
    end)
  end

  defp header_value(_, _), do: nil
end
