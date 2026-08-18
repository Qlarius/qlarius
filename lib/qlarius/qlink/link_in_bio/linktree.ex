defmodule Qlarius.Qlink.LinkInBio.Linktree do
  @moduledoc """
  Linktree parser. Prefers `__NEXT_DATA__` JSON; falls back to Generic DOM parse.

  Modern Linktree pages use `GROUP` (or `HEADER`) rows as sections, with
  each link pointing at its parent group via `parent.id`. Older pages
  interleave headers with links in list order.
  """

  alias Qlarius.Qlink.LinkInBio.{Draft, Generic, ParseHelpers}

  @section_types ~w(group header heading section)

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

    {sections, socials_from_links} = group_into_sections(links_raw)
    social_links = Map.merge(socials_from_account, socials_from_links)
    links = Enum.flat_map(sections, & &1.links)

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
        social_links: social_links,
        sections: sections,
        warnings: warnings
      }
    end
  end

  defp group_into_sections(items) when is_list(items) do
    section_items = Enum.filter(items, &section_item?/1)

    {content, socials} =
      Enum.reduce(items, {[], %{}}, fn item, {content, socials} ->
        if section_item?(item) do
          {content, socials}
        else
          case content_entry(item) do
            nil ->
              {content, socials}

            {:social, url} ->
              {content, Map.merge(socials, ParseHelpers.extract_social_links([url]))}

            entry ->
              {content ++ [entry], socials}
          end
        end
      end)

    sections =
      cond do
        section_items == [] ->
          [ParseHelpers.section_map(nil, Enum.map(content, & &1.link))]

        Enum.any?(content, & &1.parent_id) ->
          sections_from_parents(section_items, content)

        true ->
          sections_from_sequence(items)
      end

    {reject_empty_sections(sections), socials}
  end

  defp group_into_sections(_), do: {[ParseHelpers.section_map(nil, [])], %{}}

  defp sections_from_parents(section_items, content) do
    groups =
      section_items
      |> Enum.sort_by(&item_position/1)
      |> Enum.map(fn item ->
        id = item_id(item)
        {id, ParseHelpers.section_map(section_title(item), [], section_description(item))}
      end)

    group_ids = MapSet.new(groups, fn {id, _} -> id end)
    group_map = Map.new(groups)

    {group_map, orphans} =
      Enum.reduce(content, {group_map, []}, fn entry, {acc, orphans} ->
        parent_id = entry.parent_id

        cond do
          is_binary(parent_id) and MapSet.member?(group_ids, parent_id) ->
            section = acc[parent_id]
            updated = %{section | links: section.links ++ [entry]}
            {Map.put(acc, parent_id, updated), orphans}

          true ->
            {acc, orphans ++ [entry]}
        end
      end)

    named =
      Enum.map(groups, fn {id, _} ->
        section = group_map[id]
        links = sort_entries(section.links)
        %{section | links: links}
      end)
      |> Enum.reject(&(&1.links == []))

    orphan_links = sort_entries(orphans)

    if orphan_links == [] do
      named
    else
      [ParseHelpers.section_map(nil, orphan_links) | named]
    end
  end

  defp sections_from_sequence(items) do
    {sections, current} =
      Enum.reduce(items, {[], nil}, fn item, {sections, current} ->
        cond do
          section_item?(item) ->
            flushed = flush_current(sections, current)
            next = ParseHelpers.section_map(section_title(item), [], section_description(item))
            {flushed, next}

          true ->
            case content_entry(item) do
              %{link: link} ->
                current = current || ParseHelpers.section_map(nil, [])
                {sections, %{current | links: current.links ++ [link]}}

              _ ->
                {sections, current}
            end
        end
      end)

    flush_current(sections, current)
  end

  defp flush_current(sections, nil), do: sections
  defp flush_current(sections, current), do: sections ++ [current]

  defp reject_empty_sections(sections) do
    case Enum.reject(sections, &(&1.links == [])) do
      [] -> [ParseHelpers.section_map(nil, [])]
      kept -> kept
    end
  end

  defp sort_entries(entries) do
    entries
    |> Enum.sort_by(& &1.position)
    |> Enum.map(& &1.link)
  end

  defp section_item?(item) when is_map(item) do
    type?(item, @section_types) and not usable_url?(item)
  end

  defp section_item?(_), do: false

  defp type?(item, types) do
    type =
      (item["type"] || "")
      |> to_string()
      |> String.downcase()

    type in types
  end

  defp usable_url?(item) do
    url = item_url(item)
    is_binary(url) and url != "" and not ParseHelpers.junk_href?(url)
  end

  defp content_entry(item) when is_map(item) do
    url = item_url(item)

    if is_binary(url) and url != "" and not ParseHelpers.junk_href?(url) do
      if ParseHelpers.social_platform(url) do
        {:social, url}
      else
        title = item["title"] || item["text"] || item["name"]
        thumb = item["thumbnail"] || item["thumbnailUrl"] || item["imageUrl"] || get_in(item, ["modifiers", "thumbnailUrl"])

        %{
          parent_id: parent_id(item),
          position: item_position(item),
          link: ParseHelpers.link_map(title, url, thumb)
        }
      end
    else
      nil
    end
  end

  defp content_entry(_), do: nil

  defp item_url(item) do
    item["url"] || item["originalUrl"] || item["href"]
  end

  defp item_id(%{"id" => id}) when not is_nil(id), do: to_string(id)
  defp item_id(_), do: nil

  defp parent_id(%{"parent" => %{"id" => id}}) when not is_nil(id), do: to_string(id)
  defp parent_id(%{"parent" => id}) when is_integer(id), do: to_string(id)
  defp parent_id(%{"parent" => id}) when is_binary(id) and id != "", do: id
  defp parent_id(_), do: nil

  defp item_position(%{"position" => n}) when is_integer(n), do: n

  defp item_position(%{"position" => n}) when is_binary(n) do
    case Integer.parse(n) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp item_position(_), do: 0

  defp section_title(item) do
    item["title"] || item["text"] || item["name"]
  end

  defp section_description(item) do
    item["description"] || get_in(item, ["context", "description"])
  end
end
