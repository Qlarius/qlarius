defmodule QlariusWeb.Uploaders.VideoPoster do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, _scope) do
    "uploads/media_pieces/videos/posters"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .png .gif .webp)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end

  def default_url(_version, _scope), do: nil
end
