defmodule QlariusWeb.Uploaders.ContentGroupImage do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, {_file, %{id: id} = _scope}) do
    "uploads/content_groups/image/#{id}"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png .webp)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end
end
