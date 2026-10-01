defmodule QlariusWeb.Api.Admin.ContentGroupController do
  use QlariusWeb, :controller

  import Ecto.Query

  alias Qlarius.Creators.Creator
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPack, ContentPiece, RssImporter}
  alias QlariusWeb.Api.Admin.Responder

  def creators(conn, _params) do
    creators =
      Repo.all(
        from c in Creator,
          order_by: [asc: c.name],
          preload: [catalogs: ^from(cat in Catalog, order_by: [asc: cat.name])]
      )

    json(conn, %{
      creators:
        Enum.map(creators, fn creator ->
          %{
            id: creator.id,
            name: creator.name,
            catalogs:
              Enum.map(creator.catalogs, fn catalog ->
                %{
                  id: catalog.id,
                  name: catalog.name,
                  type: catalog.type,
                  group_type: catalog.group_type,
                  piece_type: catalog.piece_type
                }
              end)
          }
        end)
    })
  end

  def index(conn, params) do
    case integer(params["catalog_id"]) do
      nil ->
        Responder.error(conn, :catalog_not_found)

      catalog_id ->
        piece_counts =
          from p in ContentPiece,
            where: is_nil(p.archived_at),
            group_by: p.content_group_id,
            select: %{content_group_id: p.content_group_id, count: count(p.id)}

        groups =
          Repo.all(
            from g in ContentGroup,
              left_join: c in subquery(piece_counts),
              on: c.content_group_id == g.id,
              where: g.catalog_id == ^catalog_id,
              order_by: [asc: g.title],
              select: {g, coalesce(c.count, 0)}
          )

        json(conn, %{
          content_groups:
            Enum.map(groups, fn {group, count} ->
              group |> ContentPack.group_json() |> Map.put(:piece_count, count)
            end)
        })
    end
  end

  def pack(conn, params) do
    case ContentPack.apply(params) do
      {:ok, detail} -> json(conn, detail)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def rss_preview(conn, params) do
    case RssImporter.preview(params["feed_url"]) do
      {:ok, preview} ->
        json(conn, %{
          feed_url: preview.feed_url,
          channel: preview.channel,
          seasons: preview.seasons,
          renumbered_seasons: preview.renumbered_seasons,
          items: Enum.map(preview.items, &item_json/1)
        })

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def rss_import(conn, params) do
    case RssImporter.import_feed(params) do
      {:ok, detail} -> json(conn, detail)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def sync(conn, %{"id" => id} = params) do
    with group_id when is_integer(group_id) <- integer(id),
         %ContentGroup{} = group <- Repo.get(ContentGroup, group_id),
         {:ok, detail} <- sync_or_reorder(group, params["reorder"] in [true, "true", "episode"]) do
      json(conn, detail)
    else
      nil -> Responder.error(conn, :not_found)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp sync_or_reorder(group, false), do: RssImporter.sync_group(group)

  defp sync_or_reorder(%ContentGroup{feed_url: url} = group, true)
       when is_binary(url) and url != "" do
    with {:ok, detail} <- RssImporter.reorder_by_episode(group) do
      {:ok, Map.put(detail, :reordered, true)}
    end
  end

  defp sync_or_reorder(_group, true), do: {:error, :no_feed_url}

  defp item_json(item) do
    %{
      guid: item.guid,
      title: item.title,
      description: item.description,
      date_published: item.date_published,
      published_at: item.published_at,
      length_seconds: item.length_seconds,
      season: item.season,
      episode_number: item.episode_number,
      feed_episode_number: item.feed_episode_number,
      episode_type: item.episode_type,
      audio_url: item.enclosure_url,
      audio_type: item.enclosure_type,
      image_url: item.image_url,
      link: item.link
    }
  end

  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp integer(_), do: nil
end
