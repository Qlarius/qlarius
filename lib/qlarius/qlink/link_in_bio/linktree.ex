defmodule Qlarius.Qlink.LinkInBio.Linktree do
  @moduledoc """
  Linktree parser. Prefers `__NEXT_DATA__` JSON; falls back to Generic DOM parse.
  """

  alias Qlarius.Qlink.LinkInBio.{Draft, Generic, ParseHelpers}

  def parse(html, source_url) when is_binary(html) and is_binary(source_url) do
    case ParseHelpers.decode_next_data(html) do
      {:ok, data} ->
        from_next_data(data, source_url, html)

      _ ->
        draft = Generic.parse(html, source_url)
        %{draft | platform: :linktree, warnings: ["Used generic DOM parse for Linktree." | draft.warnings]}
    end
  end

  defp from_next_data(data, source_url, html) do
    account =
      ParseHelpers.get_in_any(data, [
        ["props", "pageProps", "account"],
        ["props", "pageProps", "socialLinksPageProps", "account"],
        ["props", "pageProps", "user"]
      ]) || %{}

    links_raw =
      ParseHelpers.get_in_any(data, [
        ["props", "pageProps", "links"],
        ["props", "pageProps", "socialLinksPageProps", "links"],
        ["props", "pageProps", "account", "links"]
      ]) || []

    username =
      account["username"] || account["name"] || ParseHelpers.username_from_path(source_url)

    title = account["pageTitle"] || account["title"] || account["name"] || username || "Linktree"
    bio = account["description"] || account["bio"] || account["customBio"]

    avatar =
      account["profilePictureUrl"] || account["profile_picture_url"] ||
        account["avatarUrl"] || account["profilePicture"]

    socials_from_account =
      case account["socialLinks"] || account["socials"] do
        list when is_list(list) ->
          list
          |> Enum.map(fn
            %{"url" => url} -> url
            %{"href" => url} -> url
            url when is_binary(url) -> url
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)
          |> ParseHelpers.extract_social_links()

        map when is_map(map) ->
          map
          |> Enum.map(fn {_k, v} -> if is_binary(v), do: v end)
          |> Enum.reject(&is_nil/1)
          |> ParseHelpers.extract_social_links()

        _ ->
          %{}
      end

    links =
      links_raw
      |> Enum.flat_map(&normalize_link/1)
      |> Enum.reject(fn link -> ParseHelpers.social_platform(link.url) end)

    warnings =
      if links == [] do
        ["Linktree JSON had no links; falling back to DOM."]
      else
        []
      end

    if links == [] do
      draft = Generic.parse(html, source_url)
      %{draft | platform: :linktree, warnings: warnings ++ draft.warnings}
    else
      %Draft{
        platform: :linktree,
        source_url: source_url,
        suggested_alias: Draft.sanitize_alias(username),
        title: title,
        bio_text: bio && String.slice(to_string(bio), 0, 500),
        avatar_url: avatar && ParseHelpers.absolutize(avatar, source_url),
        social_links: socials_from_account,
        sections: [%{title: nil, links: links}],
        warnings: warnings
      }
    end
  end

  defp normalize_link(%{"type" => type} = link)
       when type in ["HEADER", "header", "GROUP", "group"] do
    # Headers become section titles with no URL — skip as link; caller may later group.
    # For v1 keep flat: ignore header-only rows.
    _ = link
    []
  end

  defp normalize_link(link) when is_map(link) do
    url = link["url"] || link["originalUrl"] || link["href"]
    title = link["title"] || link["text"] || link["name"]
    thumb = link["thumbnail"] || link["thumbnailUrl"] || link["imageUrl"] || get_in(link, ["modifiers", "thumbnailUrl"])

    if is_binary(url) and url != "" and not ParseHelpers.junk_href?(url) do
      [ParseHelpers.link_map(title, url, thumb)]
    else
      []
    end
  end

  defp normalize_link(_), do: []
end
