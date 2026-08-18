defmodule Qlarius.Qlink.LinkInBio.Beacons do
  @moduledoc """
  Beacons.ai parser. Prefers `__NEXT_DATA__` JSON; falls back to Generic DOM parse.
  """

  alias Qlarius.Qlink.LinkInBio.{Draft, Generic, ParseHelpers}

  def parse(html, source_url) when is_binary(html) and is_binary(source_url) do
    case ParseHelpers.decode_next_data(html) do
      {:ok, data} ->
        from_next_data(data, source_url, html)

      _ ->
        draft = Generic.parse(html, source_url)
        %{draft | platform: :beacons, warnings: ["Used generic DOM parse for Beacons." | draft.warnings]}
    end
  end

  defp from_next_data(data, source_url, html) do
    page_props = get_in(data, ["props", "pageProps"]) || %{}

    profile =
      ParseHelpers.get_in_any(page_props, [
        ["profile"],
        ["user"],
        ["beacon"],
        ["page"],
        ["initialProfile"]
      ]) || page_props

    username =
      profile["username"] || profile["userName"] || profile["handle"] ||
        ParseHelpers.username_from_path(source_url)

    title =
      profile["displayName"] || profile["name"] || profile["title"] || username || "Beacons"

    bio = profile["bio"] || profile["description"] || profile["about"]

    avatar =
      profile["profileImage"] || profile["profileImageUrl"] || profile["avatar"] ||
        profile["imageUrl"] || profile["photoUrl"]

    blocks =
      ParseHelpers.get_in_any(page_props, [
        ["blocks"],
        ["links"],
        ["components"],
        ["profile", "blocks"],
        ["beacon", "blocks"]
      ]) || []

    {sections, flat_links, socials} = reduce_blocks(blocks, source_url)

    social_links =
      Map.merge(
        socials,
        case profile["socialLinks"] || profile["socials"] do
          list when is_list(list) ->
            list
            |> Enum.map(fn
              %{"url" => u} -> u
              %{"href" => u} -> u
              u when is_binary(u) -> u
              _ -> nil
            end)
            |> Enum.reject(&is_nil/1)
            |> ParseHelpers.extract_social_links()

          _ ->
            %{}
        end
      )

    if sections == [] and flat_links == [] do
      draft = Generic.parse(html, source_url)
      %{draft | platform: :beacons, warnings: ["Beacons JSON had no links; used generic DOM." | draft.warnings]}
    else
      final_sections =
        cond do
          sections == [] ->
            [ParseHelpers.section_map(nil, flat_links)]

          flat_links == [] ->
            Enum.reject(sections, &(&1.links == []))

          true ->
            [ParseHelpers.section_map(nil, flat_links) | Enum.reject(sections, &(&1.links == []))]
        end

      if Enum.flat_map(final_sections, & &1.links) == [] do
        draft = Generic.parse(html, source_url)
        %{draft | platform: :beacons, warnings: ["Beacons JSON had no links; used generic DOM." | draft.warnings]}
      else
        %Draft{
          platform: :beacons,
          source_url: source_url,
          suggested_alias: Draft.sanitize_alias(username),
          title: title,
          bio_text: bio && String.slice(to_string(bio), 0, 500),
          avatar_url: avatar && ParseHelpers.absolutize(to_string(avatar), source_url),
          social_links: social_links,
          sections: final_sections,
          warnings: []
        }
      end
    end
  end

  defp reduce_blocks(blocks, source_url) when is_list(blocks) do
    Enum.reduce(blocks, {[], [], %{}}, fn block, {sections, links, socials} ->
      type = block_type(block)

      cond do
        type in ["header", "section", "heading", "title"] ->
          title = block["title"] || block["text"] || block["name"]
          description = block["description"] || block["subtitle"]
          {sections ++ [ParseHelpers.section_map(title, [], description)], links, socials}

        type in ["link", "button", "url", "custom_link"] ->
          case block_to_link(block, source_url) do
            nil ->
              {sections, links, socials}

            link ->
              if ParseHelpers.social_platform(link.url) do
                {sections, links, Map.merge(socials, ParseHelpers.extract_social_links([link.url]))}
              else
                case List.last(sections) do
                  %{title: _, links: _} = last ->
                    updated = %{last | links: last.links ++ [link]}
                    {List.replace_at(sections, -1, updated), links, socials}

                  nil ->
                    {sections, links ++ [link], socials}
                end
              end
          end

        type in ["social", "socials", "social_icons"] ->
          urls =
            (block["links"] || block["items"] || [])
            |> Enum.map(fn
              %{"url" => u} -> u
              %{"href" => u} -> u
              u when is_binary(u) -> u
              _ -> nil
            end)
            |> Enum.reject(&is_nil/1)

          {sections, links, Map.merge(socials, ParseHelpers.extract_social_links(urls))}

        true ->
          case block_to_link(block, source_url) do
            nil -> {sections, links, socials}
            link -> {sections, links ++ [link], socials}
          end
      end
    end)
  end

  defp reduce_blocks(_, _), do: {[], [], %{}}

  defp block_type(block) when is_map(block) do
    (block["type"] || block["blockType"] || block["kind"] || "")
    |> to_string()
    |> String.downcase()
  end

  defp block_type(_), do: ""

  defp block_to_link(block, source_url) when is_map(block) do
    url = block["url"] || block["href"] || block["link"] || get_in(block, ["data", "url"])
    title = block["title"] || block["text"] || block["label"] || block["name"]
    thumb = block["image"] || block["thumbnail"] || block["thumbnailUrl"] || block["imageUrl"]

    if is_binary(url) and url != "" and not ParseHelpers.junk_href?(url) do
      ParseHelpers.link_map(
        title,
        ParseHelpers.absolutize(url, source_url),
        thumb && ParseHelpers.absolutize(to_string(thumb), source_url)
      )
    else
      nil
    end
  end

  defp block_to_link(_, _), do: nil
end
