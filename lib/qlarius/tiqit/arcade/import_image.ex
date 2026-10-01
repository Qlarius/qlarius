defmodule Qlarius.Tiqit.Arcade.ImportImage do
  @moduledoc """
  Downloads a remote image and stores it with `CreatorImage`, returning the
  stored filename. Shared by the YouTube, RSS, and content pack imports.

  `scope` must resolve to a creator directory in `CreatorImage.storage_dir/2`,
  for example a `%ContentGroup{catalog: %Catalog{}}`.
  """

  alias Qlarius.Tiqit.Arcade.ImportHttp
  alias QlariusWeb.Uploaders.CreatorImage

  @extensions %{
    "image/jpeg" => ".jpg",
    "image/jpg" => ".jpg",
    "image/png" => ".png",
    "image/gif" => ".gif",
    "image/webp" => ".webp"
  }

  def store(url, scope, basename) when is_binary(url) and url != "" do
    with {:ok, %{body: body, content_type: content_type}} <- ImportHttp.get(url),
         {:ok, ext} <- extension(url, content_type) do
      # Stored files share one directory per creator, so every name must be
      # unique or a later import overwrites an earlier group's artwork.
      name = "#{safe_basename(basename)}-#{random_suffix()}"
      tmp_path = Path.join(System.tmp_dir!(), "#{name}#{ext}")

      try do
        File.write!(tmp_path, body)

        upload = %Plug.Upload{
          path: tmp_path,
          filename: "#{name}#{ext}",
          content_type: content_type || "image/jpeg"
        }

        case CreatorImage.store({upload, scope}) do
          {:ok, filename} -> {:ok, filename}
          other -> {:error, "Failed to store image: #{inspect(other)}"}
        end
      rescue
        error in File.Error -> {:error, "Failed to store image: #{Exception.message(error)}"}
      after
        File.rm(tmp_path)
      end
    end
  end

  def store(_url, _scope, _basename), do: {:ok, nil}

  defp extension(url, content_type) do
    path_ext =
      url |> URI.parse() |> Map.get(:path) |> to_string() |> Path.extname() |> String.downcase()

    cond do
      path_ext in [".jpg", ".jpeg", ".png", ".gif", ".webp"] ->
        {:ok, path_ext}

      ext = Map.get(@extensions, content_type) ->
        {:ok, ext}

      is_binary(content_type) and not String.starts_with?(content_type, "image/") ->
        {:error, "Not an image"}

      true ->
        {:ok, ".jpg"}
    end
  end

  defp random_suffix,
    do: :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower, padding: false)

  @doc false
  def safe_basename(basename) do
    basename = to_string(basename)
    hash = :crypto.hash(:sha256, basename) |> Base.encode16(case: :lower) |> binary_part(0, 8)

    readable =
      basename
      |> String.replace(~r/[^A-Za-z0-9_-]+/, "-")
      |> String.trim("-")
      |> then(&String.slice(&1, max(String.length(&1) - 60, 0), 60))

    "#{readable}-#{hash}"
  end
end
