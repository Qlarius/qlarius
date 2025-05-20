defmodule QlariusWeb.ThreeTapBanner do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, {_file, scope}) do
    case scope do
      %{id: id} when not is_nil(id) -> "uploads/media_pieces/banners/#{id}"
      _ -> "uploads/media_pieces/banners/temp"
    end
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end

  def default_url(_version, _scope), do: "/images/default-banner.png"

end
