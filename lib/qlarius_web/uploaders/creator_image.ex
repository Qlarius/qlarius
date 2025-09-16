defmodule QlariusWeb.Uploaders.CreatorImage do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # id from scope not used - using static storage directory
  def storage_dir(_version, {_file, _scope}) do
    "uploads/creators/content_images/"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png .webp)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end
end
