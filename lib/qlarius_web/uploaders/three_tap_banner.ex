defmodule QlariusWeb.Uploaders.ThreeTapBanner do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, _scope) do
    "uploads/media_pieces/banners/three_tap_banners/"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end

  def default_url(_version, _scope), do: "/images/default-banner.png"
end
