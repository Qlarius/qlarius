defmodule Qlarius.Qlink.LinkInBio.Generic do
  @moduledoc """
  Generic link-in-bio HTML parser using Open Graph tags and anchor links.
  """

  alias Qlarius.Qlink.LinkInBio.Draft
  alias Qlarius.Qlink.LinkInBio.ParseHelpers

  @doc "Parse HTML into a `%Draft{}`. Always returns a draft (may be sparse)."
  def parse(html, source_url) when is_binary(html) and is_binary(source_url) do
    document = Floki.parse_document!(html)
    warnings = []

    title =
      ParseHelpers.meta_content(document, "og:title") ||
        document |> Floki.find("title") |> Floki.text() |> String.trim() |> blank_to_nil()

    bio =
      ParseHelpers.meta_content(document, "og:description") ||
        ParseHelpers.meta_content(document, "description")

    avatar =
      ParseHelpers.meta_content(document, "og:image")
      |> ParseHelpers.absolutize(source_url)

    anchors =
      document
      |> Floki.find("a[href]")
      |> Enum.map(fn el ->
        href = el |> Floki.attribute("href") |> List.first()
        text = el |> Floki.text() |> String.trim()
        {href, text, el}
      end)
      |> Enum.reject(fn {href, _text, _el} -> ParseHelpers.junk_href?(href) end)
      |> Enum.map(fn {href, text, el} ->
        url = ParseHelpers.absolutize(href, source_url)
        thumb = img_src_inside(el) |> ParseHelpers.absolutize(source_url)
        {url, text, thumb}
      end)
      |> Enum.uniq_by(fn {url, _, _} -> url end)

    social_urls = Enum.map(anchors, fn {url, _, _} -> url end)
    social_links = ParseHelpers.extract_social_links(social_urls)

    content_links =
      anchors
      |> Enum.reject(fn {url, _, _} -> ParseHelpers.social_platform(url) end)
      |> Enum.reject(fn {url, _, _} -> same_page?(url, source_url) end)
      |> Enum.map(fn {url, text, thumb} ->
        ParseHelpers.link_map(text, url, thumb)
      end)

    warnings =
      if content_links == [] do
        ["No content links found on page — generic parser may need a platform-specific extractor." | warnings]
      else
        warnings
      end

    %Draft{
      platform: :generic,
      source_url: source_url,
      suggested_alias: ParseHelpers.username_from_path(source_url) || Draft.sanitize_alias(title),
      title: title || "Imported page",
      bio_text: bio && String.slice(bio, 0, 500),
      avatar_url: avatar,
      social_links: social_links,
      sections: [ParseHelpers.section_map(nil, content_links)],
      warnings: Enum.reverse(warnings)
    }
  end

  defp img_src_inside(el) do
    case Floki.find(el, "img[src]") do
      [img | _] -> Floki.attribute(img, "src") |> List.first()
      _ -> nil
    end
  end

  defp same_page?(url, source_url) do
    u = URI.parse(url)
    s = URI.parse(source_url)
    u.host == s.host and normalize_path(u.path) == normalize_path(s.path)
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path(path), do: String.trim_trailing(path, "/")

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
