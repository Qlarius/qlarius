defmodule QlariusWeb.Uploaders.RecipientBrandImage do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, {_file, %{id: id} = _scope}) do
    "uploads/recipients/recipient_brand_images/"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end

  def default_url(_version, _scope) do
    "/uploads/recipients/recipient_brand_images/tipjar_love_default.png"
  end
end
