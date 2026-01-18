defmodule QlariusWeb.Uploaders.AdVideo do
  use Waffle.Definition

  @versions [:original]

  def storage_dir(_version, {_file, _scope}) do
    "uploads/media_pieces/videos"
  end

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case file_extension do
      ".mp4" -> :ok
      _ -> {:error, "Invalid file type. Only MP4 videos are supported."}
    end
  end
end
