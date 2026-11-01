defmodule Qlarius.AdminApi.ImageUrls do
  @moduledoc false

  alias Qlarius.Qlink.Urls
  alias Qlarius.Sponster.Recipient
  alias QlariusWeb.Uploaders.RecipientBrandImage

  @spec recipient_graphic_url(Recipient.t() | nil) :: String.t() | nil
  def recipient_graphic_url(nil), do: nil

  def recipient_graphic_url(%Recipient{graphic_url: nil}), do: nil

  def recipient_graphic_url(%Recipient{} = recipient) do
    RecipientBrandImage.url({recipient.graphic_url, recipient}, :original)
    |> absolute_public_url()
  end

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
