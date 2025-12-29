defmodule QlariusWeb.Helpers.ImageHelpers do
  alias QlariusWeb.Uploaders.CreatorImage

  @doc """
  Returns the appropriate image URL following the hierarchy:
  content_piece -> content_group -> catalog -> creator -> placeholder

  Accepts either just a content_piece (if fully preloaded) or content_piece + content_group
  """
  def content_image_url(content_piece, content_group \\ nil)

  def content_image_url(content_piece, content_group) when not is_nil(content_group) do
    cond do
      content_piece.image ->
        # Create a properly structured content piece for the uploader
        enhanced_piece = %{content_piece | content_group: content_group}
        CreatorImage.url({content_piece.image, enhanced_piece}, :original)

      content_group.image ->
        CreatorImage.url({content_group.image, content_group}, :original)

      Ecto.assoc_loaded?(content_group.catalog) && content_group.catalog.image ->
        CreatorImage.url({content_group.catalog.image, content_group.catalog}, :original)

      Ecto.assoc_loaded?(content_group.catalog) &&
        Ecto.assoc_loaded?(content_group.catalog.creator) &&
          content_group.catalog.creator.image ->
        CreatorImage.url(
          {content_group.catalog.creator.image, content_group.catalog.creator},
          :original
        )

      true ->
        placeholder_image_url()
    end
  end

  def content_image_url(content_piece, nil) do
    # Fallback for when content_group is not provided - only use content_piece image or placeholder
    if content_piece.image do
      CreatorImage.url({content_piece.image, content_piece}, :original)
    else
      placeholder_image_url()
    end
  end

  @doc """
  Returns the appropriate image URL for a content group following the hierarchy:
  content_group -> catalog -> creator -> placeholder
  """
  def group_image_url(content_group) do
    cond do
      content_group.image ->
        CreatorImage.url({content_group.image, content_group}, :original)

      Ecto.assoc_loaded?(content_group.catalog) && content_group.catalog.image ->
        CreatorImage.url({content_group.catalog.image, content_group.catalog}, :original)

      Ecto.assoc_loaded?(content_group.catalog) &&
        Ecto.assoc_loaded?(content_group.catalog.creator) &&
          content_group.catalog.creator.image ->
        CreatorImage.url(
          {content_group.catalog.creator.image, content_group.catalog.creator},
          :original
        )

      true ->
        placeholder_image_url()
    end
  end

  @doc """
  Returns the appropriate image URL for a catalog following the hierarchy:
  catalog -> creator -> placeholder
  """
  def catalog_image_url(catalog) do
    cond do
      catalog.image ->
        CreatorImage.url({catalog.image, catalog}, :original)

      Ecto.assoc_loaded?(catalog.creator) && catalog.creator.image ->
        CreatorImage.url({catalog.creator.image, catalog.creator}, :original)

      true ->
        placeholder_image_url()
    end
  end

  @doc """
  Returns the appropriate image URL for a creator or placeholder
  """
  def creator_image_url(creator) do
    if creator.image do
      CreatorImage.url({creator.image, creator}, :original)
    else
      placeholder_image_url()
    end
  end

  @doc """
  Returns a placeholder image URL
  """
  def placeholder_image_url do
    "/images/placeholder-image.svg"
  end
end
