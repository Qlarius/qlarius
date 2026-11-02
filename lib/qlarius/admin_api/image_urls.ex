defmodule Qlarius.AdminApi.ImageUrls do
  @moduledoc false

  alias Qlarius.Qlink.Urls
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPiece}
  alias QlariusWeb.Uploaders.{CreatorImage, RecipientBrandImage}

  @spec recipient_graphic_url(Recipient.t() | nil) :: String.t() | nil
  def recipient_graphic_url(nil), do: nil

  def recipient_graphic_url(%Recipient{graphic_url: nil}), do: nil

  def recipient_graphic_url(%Recipient{} = recipient) do
    RecipientBrandImage.url({recipient.graphic_url, recipient}, :original)
    |> absolute_public_url()
  end

  @doc """
  Absolute public URL for a creator, catalog, group, or piece image.
  """
  def content_image_url(%{image: image} = record) when is_binary(image) and image != "" do
    record
    |> image_scope()
    |> then(fn scope -> CreatorImage.url({image, scope}, :original) end)
    |> absolute_public_url()
  end

  def content_image_url(_record), do: nil

  defp image_scope(%ContentPiece{} = piece), do: Repo.preload(piece, content_group: :catalog)
  defp image_scope(%ContentGroup{} = group), do: Repo.preload(group, :catalog)
  defp image_scope(record), do: record

  defp absolute_public_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] ->
        url

      _ ->
        path =
          case url do
            "/" <> _ -> url
            other -> "/" <> other
          end

        Urls.public_app_url(path)
    end
  end
end
