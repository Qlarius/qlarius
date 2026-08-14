defmodule Qlarius.Qlink.LinkInBio.ParseHelpers do
  @moduledoc false

  alias Qlarius.Qlink.LinkInBio.Draft

  @social_hosts %{
    "twitter.com" => "twitter",
    "x.com" => "twitter",
    "instagram.com" => "instagram",
    "threads.com" => "threads",
    "threads.net" => "threads",
    "facebook.com" => "facebook",
    "fb.com" => "facebook",
    "linkedin.com" => "linkedin",
    "youtube.com" => "youtube",
    "youtu.be" => "youtube",
    "tiktok.com" => "tiktok",
    "github.com" => "github"
  }

  def meta_content(document, property) do
    selectors = [
      ~s(meta[property="#{property}"]),
      ~s(meta[name="#{property}"])
    ]

    Enum.find_value(selectors, fn sel ->
      case Floki.find(document, sel) do
        [el | _] -> Floki.attribute(el, "content") |> List.first()
        _ -> nil
      end
    end)
  end

  def absolutize(nil, _base), do: nil
  def absolutize("", _base), do: nil

  def absolutize(url, base) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme in ["http", "https"] ->
        url

      String.starts_with?(url, "//") ->
        "https:" <> url

      true ->
        base_uri = URI.parse(base)
        URI.merge(base_uri, url) |> URI.to_string()
    end
  rescue
    _ -> url
  end

  def extract_social_links(urls) when is_list(urls) do
    urls
    |> Enum.reduce(%{}, fn url, acc ->
      case social_platform(url) do
        nil -> acc
        platform -> Map.put_new(acc, platform, url)
      end
    end)
  end

  def social_platform(url) when is_binary(url) do
    host =
      url
      |> URI.parse()
      |> Map.get(:host)
      |> case do
        nil -> nil
        h -> h |> String.downcase() |> String.replace_prefix("www.", "")
      end

    Map.get(@social_hosts, host)
  end

  def social_platform(_), do: nil

  def link_map(title, url, thumbnail_url \\ nil) do
    %{
      title: present_or(title, fallback_title(url)),
      url: url,
      thumbnail_url: thumbnail_url,
      include?: true
    }
  end

  def present_or(nil, fallback), do: fallback
  def present_or("", fallback), do: fallback
  def present_or(value, _fallback) when is_binary(value), do: String.trim(value)
  def present_or(_, fallback), do: fallback

  def fallback_title(nil), do: "Link"

  def fallback_title(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> "Link"
    end
  end

  def username_from_path(url) do
    path = URI.parse(url).path || ""

    path
    |> String.trim("/")
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
    |> List.first()
    |> Draft.sanitize_alias()
  end

  def decode_next_data(html) when is_binary(html) do
    case Regex.run(~r/<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s, html) do
      [_, json] ->
        case Jason.decode(json) do
          {:ok, data} -> {:ok, data}
          error -> error
        end

      _ ->
        :error
    end
  end

  def get_in_any(map, paths) when is_map(map) and is_list(paths) do
    Enum.find_value(paths, fn path ->
      case get_in(map, path) do
        nil -> nil
        "" -> nil
        value -> value
      end
    end)
  end

  def junk_href?(href) when is_binary(href) do
    href = String.trim(href)
    lower = String.downcase(href)

    href == "" or href == "#" or
      String.starts_with?(lower, "javascript:") or
      String.starts_with?(lower, "mailto:") or
      String.starts_with?(lower, "tel:") or
      String.starts_with?(lower, "data:")
  end

  def junk_href?(_), do: true
end
