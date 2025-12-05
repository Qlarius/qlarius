defmodule QlariusWeb.LiveView.ImageUpload do
  @moduledoc """
  Helper functions for handling image uploads in LiveViews.

  Provides standardized configuration and consumption logic for image uploads.
  """

  @doc """
  Sets up image upload configuration on a socket.

  ## Options

    * `:upload_name` - The name of the upload (default: `:image`)
    * `:auto_upload` - Whether to auto-upload files (default: `false`)
    * `:max_file_size` - Maximum file size in bytes (default: `10_000_000`)
    * `:accept` - List of accepted file extensions (default: `~w(.jpg .jpeg .png .gif .webp)`)

  ## Examples

      socket = ImageUpload.setup_upload(socket, :image, auto_upload: true)

  """
  def setup_upload(socket, upload_name \\ :image, opts \\ []) do
    auto_upload = Keyword.get(opts, :auto_upload, false)
    max_file_size = Keyword.get(opts, :max_file_size, 10_000_000)
    accept = Keyword.get(opts, :accept, ~w(.jpg .jpeg .png .gif .webp))

    socket
    |> Phoenix.LiveView.allow_upload(upload_name,
      accept: accept,
      max_entries: 1,
      max_file_size: max_file_size,
      auto_upload: auto_upload
    )
  end

  @doc """
  Consumes uploaded entries and stores them using the provided uploader module.

  Returns the params map with the image filename added if upload was successful.

  ## Examples

      params = ImageUpload.consume_upload(socket, :image, @creator, CreatorImage)

  """
  def consume_upload(socket, upload_name \\ :image, scope, uploader_module) do
    case Phoenix.LiveView.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
           upload = %Plug.Upload{
             path: path,
             filename: entry.client_name,
             content_type: entry.client_type
           }

           case uploader_module.store({upload, scope}) do
             {:ok, filename} -> {:ok, filename}
             error -> error
           end
         end) do
      [{:ok, filename} | _] -> filename
      [filename | _] when is_binary(filename) -> filename
      _ -> nil
    end
  end

  @doc """
  Consumes uploaded entries and adds the filename to params map.

  Returns the params map with the image field added if upload was successful.

  ## Examples

      params = ImageUpload.consume_and_add_to_params(
        socket,
        :image,
        @creator,
        CreatorImage,
        %{"name" => "Test"}
      )

  """
  def consume_and_add_to_params(socket, upload_name \\ :image, scope, uploader_module, params) do
    case consume_upload(socket, upload_name, scope, uploader_module) do
      nil -> params
      filename -> Map.put(params, "image", filename)
    end
  end
end
