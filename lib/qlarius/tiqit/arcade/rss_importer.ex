defmodule Qlarius.Tiqit.Arcade.RssImporter do
  @moduledoc """
  Turns a podcast RSS feed into a content pack and applies it with
  `ContentPack`.

  Feed items are filtered by season and episode type, ordered oldest
  first, and imported as audio pieces keyed by their `guid`. The feed
  settings are stored on the group so `sync_group/1` can add new episodes
  later.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPack, Creators, RssFeed}

  @default_episode_types ["full", "trailer"]

  def default_episode_types, do: @default_episode_types

  @doc """
  Fetches a feed and returns `{:ok, %{channel, seasons, items, renumbered_seasons}}`.

  Items are in publish order. `episode_number` is the number an import will
  store (see `number_episodes/1`); `feed_episode_number` is what the feed says.
  """
  def preview(feed_url) do
    with {:ok, url} <- feed_url(feed_url),
         {:ok, feed} <- RssFeed.fetch(url) do
      sorted =
        feed.items
        |> Enum.uniq_by(& &1.guid)
        |> Enum.map(&Map.put(&1, :feed_episode_number, &1.episode_number))
        |> Enum.sort_by(&RssFeed.sort_key/1)

      {items, renumbered} = number_episodes(sorted)

      {:ok,
       Map.merge(feed, %{
         feed_url: url,
         items: items,
         seasons: RssFeed.seasons(items),
         renumbered_seasons: renumbered
       })}
    end
  end

  @doc """
  Imports a feed. String keys, as from the API or the wizard:

    * `"feed_url"` (required) and `"catalog_id"` (required)
    * `"season"` - only items in this season; omit for every item
    * `"episode_types"` - defaults to `["full", "trailer"]`
    * `"content_group_id"` - import into this group; otherwise a group is created
    * `"group_title"` - title for a new group; defaults to the channel title
    * `"guids"` - only these items (the wizard's selection)
    * `"auto_sync"` - turn daily sync on or off
    * `"dry_run"`

  A pre-fetched `feed` (from `preview/1`) can be passed in `opts[:feed]`.
  """
  def import_feed(params, opts \\ []) when is_map(params) do
    with {:ok, url} <- feed_url(params["feed_url"]),
         {:ok, episode_types} <- episode_types(params["episode_types"]),
         {:ok, season} <- season(params["season"]),
         {:ok, feed} <- feed(url, opts) do
      {items, warnings} = select_items(feed.items, season, episode_types, params["guids"])

      pack = build_pack(params, feed, items)

      group_attrs =
        %{
          feed_url: url,
          feed_season: season,
          feed_episode_types: episode_types,
          last_synced_at: now()
        }
        |> maybe_put(:feed_auto_sync, auto_sync(params["auto_sync"]))

      pack_opts = [
        source_provider: "rss",
        group_attrs: group_attrs,
        refresh_fields: Keyword.get(opts, :refresh_fields, default_refresh_fields())
      ]

      case ContentPack.apply(pack, pack_opts) do
        {:ok, detail} -> {:ok, Map.update!(detail, :warnings, &(warnings ++ &1))}
        error -> error
      end
    end
  end

  @doc """
  Re-reads a group's stored feed. New `guid`s are added; existing pieces
  only get their audio URL, duration, and episode fields refreshed, so
  titles and descriptions edited by hand are kept.
  """
  def sync_group(%ContentGroup{feed_url: url} = group) when is_binary(url) and url != "" do
    params = %{
      "feed_url" => url,
      "catalog_id" => group.catalog_id,
      "content_group_id" => group.id,
      "season" => group.feed_season,
      "episode_types" => sync_episode_types(group)
    }

    import_feed(params,
      refresh_fields: [:file_url, :length, :season, :episode_number, :episode_type]
    )
  end

  def sync_group(%ContentGroup{}), do: {:error, :no_feed_url}

  @doc """
  Puts a group's pieces in episode order: trailers, then episodes by number,
  then bonus items. A group with a feed is synced first, so episode numbers
  are refreshed from the feed before sorting.

  Returns `{:ok, sync_detail | nil}`.
  """
  def reorder_by_episode(%ContentGroup{} = group) do
    with {:ok, detail} <- maybe_sync(group),
         group = Creators.get_content_group!(group.id),
         active = ContentGroup.active_content_pieces(group.content_pieces),
         {:ok, _group} <-
           Creators.restripe_content_pieces(
             group,
             ContentGroup.sort_pieces_by_preset(active, "episode")
           ) do
      {:ok, detail}
    end
  end

  defp maybe_sync(%ContentGroup{feed_url: url} = group) when is_binary(url) and url != "",
    do: sync_group(group)

  defp maybe_sync(_group), do: {:ok, nil}

  def set_auto_sync(%ContentGroup{} = group, enabled?) when is_boolean(enabled?) do
    group
    |> ContentGroup.import_changeset(%{feed_auto_sync: enabled?})
    |> Repo.update()
  end

  @doc """
  Groups with daily sync turned on.
  """
  def auto_sync_groups do
    Repo.all(
      from g in ContentGroup,
        where: g.feed_auto_sync == true and not is_nil(g.feed_url)
    )
  end

  # ----- pack building -----

  defp build_pack(params, feed, items) do
    group_id = params["content_group_id"]
    mode = if blank?(group_id), do: "create", else: "update"

    content_group =
      if mode == "create" do
        %{
          "title" => first_present([params["group_title"], feed.channel.title]),
          "description" => feed.channel.description,
          "image_url" => feed.channel.image_url,
          "source_url" => feed.channel.link
        }
      else
        %{"id" => group_id}
      end

    %{
      "mode" => mode,
      "catalog_id" => params["catalog_id"],
      "content_group" => content_group,
      "pieces" => Enum.map(items, &piece(&1, episode_art(feed))),
      "dry_run" => params["dry_run"]
    }
  end

  @doc """
  Item art worth storing: guid => image URL for items whose art is their own.
  Art that matches the channel image, or that several items share, is left
  out so those pieces fall back to the group image instead of each storing
  a copy.
  """
  def episode_art(%{channel: channel, items: items}) do
    channel_art = art_key(channel.image_url)
    counts = items |> Enum.map(&art_key(&1.image_url)) |> Enum.frequencies()

    for item <- items,
        key = art_key(item.image_url),
        key != nil and key != channel_art and counts[key] == 1,
        into: %{},
        do: {item.guid, item.image_url}
  end

  defp art_key(url) when is_binary(url) and url != "" do
    uri = URI.parse(url)
    String.downcase("#{uri.host}#{uri.path}")
  end

  defp art_key(_), do: nil

  defp piece(item, episode_art) do
    %{
      "title" => item.title,
      "description" => item.description,
      "date_published" => item.date_published && Date.to_iso8601(item.date_published),
      "length_seconds" => item.length_seconds,
      "image_url" => Map.get(episode_art, item.guid),
      "source_url" => item.link,
      "external_id" => item.guid,
      "season" => item.season,
      "episode_number" => item.episode_number,
      "episode_type" => item.episode_type,
      "media" => %{"type" => "audio", "url" => item.enclosure_url}
    }
  end

  defp select_items(items, season, episode_types, guids) do
    guid_filter = if is_list(guids) and guids != [], do: MapSet.new(guids), else: nil

    {in_scope, renumbered_seasons} =
      items
      |> Enum.filter(&(is_nil(season) or &1.season == season))
      |> Enum.filter(&(&1.episode_type in episode_types))
      |> Enum.uniq_by(& &1.guid)
      |> Enum.sort_by(&RssFeed.sort_key/1)
      |> number_episodes()

    candidates =
      Enum.filter(in_scope, &(is_nil(guid_filter) or MapSet.member?(guid_filter, &1.guid)))

    {playable, unplayable} = Enum.split_with(candidates, &https_audio?/1)

    warnings =
      Enum.map(renumbered_seasons, fn season ->
        scope = if season, do: "season #{season}", else: "this feed"

        "Episode numbers in #{scope} were missing or inconsistent; numbered by publish order"
      end) ++
        Enum.map(unplayable, fn item ->
          "#{item.title || item.guid}: skipped, the feed has no https audio file for it"
        end)

    {playable, warnings}
  end

  @doc """
  Numbers full episodes in publish order, per season. A season keeps the
  feed's numbers when they already run consecutively in that order (for
  example 1..8, or 101..108); otherwise its full episodes become 1..N.
  Trailers and bonus items keep whatever the feed says.

  Takes items already sorted by `RssFeed.sort_key/1`. Returns
  `{items, renumbered_seasons}`.
  """
  def number_episodes(items) do
    renumbered =
      items
      |> Enum.group_by(& &1.season)
      |> Enum.flat_map(fn {season, season_items} ->
        full = Enum.filter(season_items, &(&1.episode_type == "full"))
        if consecutive?(Enum.map(full, & &1.episode_number)), do: [], else: [{season, full}]
      end)

    numbers =
      for {_season, full} <- renumbered,
          {item, index} <- Enum.with_index(full, 1),
          into: %{},
          do: {item.guid, index}

    items = Enum.map(items, &%{&1 | episode_number: Map.get(numbers, &1.guid, &1.episode_number)})

    {items, renumbered |> Enum.map(&elem(&1, 0)) |> Enum.sort_by(&(&1 || -1))}
  end

  defp consecutive?([]), do: true

  defp consecutive?([first | _] = numbers) when is_integer(first) do
    numbers == Enum.to_list(first..(first + length(numbers) - 1))
  end

  defp consecutive?(_), do: false

  defp https_audio?(%{enclosure_url: "https://" <> _}), do: true
  defp https_audio?(_), do: false

  # ----- params -----

  defp feed(url, opts) do
    case Keyword.get(opts, :feed) do
      %{items: _, channel: _} = feed -> {:ok, feed}
      _ -> RssFeed.fetch(url)
    end
  end

  defp feed_url(url) when is_binary(url) do
    case String.trim(url) do
      "" -> {:error, :feed_url_required}
      "http://" <> rest -> {:ok, "https://" <> rest}
      trimmed -> {:ok, trimmed}
    end
  end

  defp feed_url(_), do: {:error, :feed_url_required}

  defp episode_types(nil), do: {:ok, @default_episode_types}
  defp episode_types([]), do: {:ok, @default_episode_types}

  defp episode_types(types) when is_list(types) do
    types = Enum.map(types, &to_string/1)

    if Enum.all?(types, &(&1 in ~w(full trailer bonus))),
      do: {:ok, Enum.uniq(types)},
      else: {:error, :invalid_episode_types}
  end

  defp episode_types(_), do: {:error, :invalid_episode_types}

  defp season(nil), do: {:ok, nil}
  defp season(""), do: {:ok, nil}
  defp season(value) when is_integer(value), do: {:ok, value}

  defp season(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_season}
    end
  end

  defp season(_), do: {:error, :invalid_season}

  defp sync_episode_types(%ContentGroup{feed_episode_types: [_ | _] = types}), do: types
  defp sync_episode_types(_), do: @default_episode_types

  defp auto_sync(nil), do: nil
  defp auto_sync(value), do: value in [true, "true", "1", 1, "on"]

  defp default_refresh_fields do
    [
      :title,
      :description,
      :date_published,
      :length,
      :file_url,
      :media_type,
      :season,
      :episode_number,
      :episode_type,
      :source_url
    ]
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp first_present(values), do: Enum.find(values, &(is_binary(&1) and String.trim(&1) != ""))

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
