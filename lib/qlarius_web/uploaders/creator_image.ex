defmodule QlariusWeb.Uploaders.CreatorImage do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  # Save under a per-creator directory
  alias Qlarius.Tiqit.Arcade.{ContentGroup, Catalog, Creator, ContentPiece}

  def storage_dir(_version, {_file, %ContentGroup{catalog: %Catalog{creator_id: creator_id}}})
      when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  def storage_dir(
        _version,
        {_file, %Qlarius.Tiqit.Arcade.ContentGroup{catalog: %{creator: %{id: creator_id}}}}
      )
      when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  # Creator-scoped images (e.g. creator profile/brand images)
  def storage_dir(_version, {_file, %Creator{id: creator_id}}) when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  # Catalog-scoped images
  def storage_dir(_version, {_file, %Catalog{creator_id: creator_id}})
      when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  # ContentPiece-scoped images (piece -> group -> catalog -> creator)
  def storage_dir(
        _version,
        {_file,
         %ContentPiece{content_group: %ContentGroup{catalog: %Catalog{creator_id: creator_id}}}}
      )
      when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  # ContentPiece with loaded content_group but no deeper nesting
  def storage_dir(
        _version,
        {_file, %ContentPiece{content_group: %ContentGroup{catalog: %{creator_id: creator_id}}}}
      )
      when is_integer(creator_id) do
    "uploads/creators/#{creator_id}/"
  end

  # Fallback
  def storage_dir(_version, {_file, _scope}) do
    "uploads/creators/unknown/content_images/"
  end

  def validate({file, _}) do
    ~w(.jpg .jpeg .gif .png .webp)
    |> Enum.member?(Path.extname(file.file_name) |> String.downcase())
  end
end
