defmodule QlariusWeb.Helpers.ImageHelpers do
  import Ecto.Query

  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Uploaders.CreatorImage
  alias QlariusWeb.Uploaders.RecipientBrandImage

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

  @doc """
  Returns the brand image URL for a Sponster recipient.

  Falls back to the linked Creator's image when the recipient has no brand image.
  Pass `creator:` when the creator is already loaded to avoid an extra query.
  """
  def recipient_brand_image_url(recipient, opts \\ [])

  def recipient_brand_image_url(nil, _opts), do: placeholder_image_url()

  def recipient_brand_image_url(%Recipient{} = recipient, opts) do
    creator = Keyword.get(opts, :creator) || creator_for_recipient(recipient.id)

    cond do
      recipient.graphic_url ->
        RecipientBrandImage.url({recipient.graphic_url, recipient})

      creator && creator.image ->
        CreatorImage.url({creator.image, creator}, :original)

      true ->
        placeholder_image_url()
    end
  end

  defp creator_for_recipient(recipient_id) do
    Repo.one(
      from c in Creator,
        where: c.recipient_id == ^recipient_id,
        limit: 1
    )
  end
end
