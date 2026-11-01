defmodule QlariusWeb.Api.Admin.ContentGroupController do
  use QlariusWeb, :controller

  import Ecto.Query

  alias Qlarius.AdminApi.{ContentGroups, Prices}
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPack, ContentPiece, RssImporter}
  alias QlariusWeb.Api.Admin.Responder

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
    with :ok <- Prices.reject(params),
         {:ok, detail} <- ContentPack.apply(params) do
      json(conn, detail)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def create(conn, %{"catalog_id" => catalog_id} = params) do
    case Qlarius.AdminApi.Catalogs.fetch(catalog_id) do
      {:ok, catalog} ->
        case ContentGroups.create(catalog, params, dry_run: Responder.dry_run?(params)) do
          {:ok, %{result: "created"} = result} ->
            conn |> put_status(201) |> json(group_body(result))

          {:ok, result} ->
            json(conn, group_body(result))

          {:error, reason} ->
            Responder.error(conn, reason)
        end

      {:error, reason} ->
        Responder.error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case ContentGroups.fetch(id) do
      {:ok, group} -> json(conn, %{content_group: ContentPack.group_json(group)})
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, group} <- ContentGroups.fetch(id),
         {:ok, result} <- ContentGroups.update(group, params, dry_run: Responder.dry_run?(params)) do
      json(conn, group_body(result))
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    with {:ok, group} <- ContentGroups.fetch(id),
         {:ok, result} <- ContentGroups.delete(group, dry_run: Responder.dry_run?(params)) do
      json(conn, result)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp group_body(%{result: result, record: group, differences: differences}) do
    %{
      result: result,
      matched: result not in ~w(created would_create),
      content_group: ContentPack.group_json(group),
      differences: differences
    }
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
    with :ok <- Prices.reject(params),
         {:ok, detail} <- RssImporter.import_feed(params) do
      json(conn, detail)
    else
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  def sync(conn, %{"id" => id} = params) do
    with :ok <- Prices.reject(params),
         group_id when is_integer(group_id) <- integer(id),
         %ContentGroup{} = group <- Repo.get(ContentGroup, group_id),
         {:ok, detail} <- sync_or_reorder(group, params) do
      json(conn, detail)
    else
      nil -> Responder.error(conn, :not_found)
      {:error, reason} -> Responder.error(conn, reason)
    end
  end

  defp sync_or_reorder(group, %{"reorder" => reorder})
       when reorder in [true, "true", "episode"] do
    with {:ok, detail} <- RssImporter.reorder_by_episode(group) do
      {:ok, Map.put(detail, :reordered, true)}
    end
  end

  defp sync_or_reorder(group, params) do
    RssImporter.sync_group(group,
      refresh_existing: params["refresh_existing"] in [true, "true", "1"],
      strip_patterns: params["strip_patterns"],
      drop_patterns: params["drop_patterns"],
      dry_run: Responder.dry_run?(params)
    )
  end

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
