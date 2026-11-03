defmodule QlariusWeb.Uploaders.PromoSequenceImage do
  use Waffle.Definition

  @versions [:original]

  def storage_dir(_version, _scope) do
    "uploads/promo_sequences/"
  end

  def validate({file, _}) do
    ~w(.png .svg)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end
end
