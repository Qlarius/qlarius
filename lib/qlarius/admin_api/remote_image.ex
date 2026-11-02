defmodule Qlarius.AdminApi.RemoteImage do
  @moduledoc """
  Downloads an http(s) image and stores it with Waffle.

  `store/4` returns `%{file_name: filename, updated_at: timestamp}`.
  Recipient `graphic_url` is a Waffle field, so that map is saved and the
  public URL gains a cache-busting query. Creator, catalog, group, and piece
  `image` columns are plain strings, so `assign/4` saves `file_name`.

  Every store uses a new file name, so a replace changes the public URL even
  when the source URL differs only by a query string. The same source URL is
  left in place.
  """

  alias Qlarius.AdminApi.ImageUrls
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ImportHttp, ImportImage}

  def validate(nil), do: :ok
  def validate(""), do: :ok

  def validate(url) when is_binary(url) do
    if ImportHttp.public_url?(url, ["http", "https"]) do
      :ok
    else
      {:error, "Image URL must be an http or https URL"}
    end
  end

  def validate(_url), do: {:error, "Image URL must be an http or https URL"}

  def store(scope, url, basename, opts \\ []) do
    with :ok <- validate(url),
         {:ok, filename} <- ImportImage.store(url, scope, basename, opts) do
      case filename do
        nil ->
          {:ok, nil}

        filename ->
          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          {:ok, %{file_name: filename, updated_at: now}}
      end
    end
  end

  def assign(record, url, basename, opts \\ [])

  def assign(record, url, _basename, _opts) when url in [nil, ""], do: {:ok, record}

  def assign(record, url, basename, opts) when is_binary(url) do
    field = Keyword.get(opts, :field, :image)

    if field == :image and unchanged?(record, url) do
      {:ok, record}
    else
      case store(record, url, basename, Keyword.take(opts, [:uploader])) do
        {:ok, nil} ->
          {:ok, record}

        {:ok, %{file_name: filename} = stored} ->
          value = if field == :graphic_url, do: stored, else: filename
          changes = %{field => value}

          changes =
            if field == :image, do: Map.put(changes, :image_source_url, url), else: changes

          record
          |> Ecto.Changeset.change(changes)
          |> Repo.update()

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def assign(_record, _url, _basename, _opts) do
    {:error, "Image URL must be an http or https URL"}
  end

  @doc """
  Dry-run difference for `image_url`. Does not download or store.
  """
  def difference(record, params) do
    case params["image_url"] do
      url when is_binary(url) and url != "" ->
        if unchanged?(record, url) do
          %{}
        else
          %{
            "image" => %{
              "current" => ImageUrls.content_image_url(record),
              "requested" => url
            }
          }
        end

      _ ->
        %{}
    end
  end

  @doc """
  The stored file already came from this source URL.
  """
  def unchanged?(record, url) when is_binary(url) and url != "" do
    source = Map.get(record, :image_source_url)
    image = Map.get(record, :image)
    source == url and is_binary(image) and image != ""
  end

  def unchanged?(_record, _url), do: false

  @doc """
  An image is stored, but the source URL was never recorded.
  """
  def untracked?(record, url) when is_binary(url) and url != "" do
    image = Map.get(record, :image)
    is_binary(image) and image != "" and is_nil(Map.get(record, :image_source_url))
  end

  def untracked?(_record, _url), do: false

  @doc """
  `:keep` when the source URL is unchanged, `:remember` when an existing
  file has no recorded source, `:replace` when the file should be downloaded.
  """
  def replace_action(nil, url) when is_binary(url) and url != "", do: :replace

  def replace_action(record, url) when is_binary(url) and url != "" do
    cond do
      unchanged?(record, url) -> :keep
      untracked?(record, url) -> :remember
      true -> :replace
    end
  end

  def replace_action(_record, _url), do: :keep
end
