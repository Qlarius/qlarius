defmodule Qlarius.Tiqit.Arcade.YoutubeImporter do
  @moduledoc """
  Orchestrates YouTube **channel** or **playlist** → Tiqit Arcade import
  into an existing `%ContentGroup{}`.

    * Resolves pasted input via `Qlarius.Youtube.Client.parse_import_input/1`
      (playlist URL / `?list=` / bare playlist id vs channel handle or URL).
    * Lists all `playlistItems` (uploads playlist or any playlist id).
    * Each preview video map includes `:playlist_position` so imports can
      keep `display_order` aligned with playlist order.

  Per-video failures are caught and reported in the result list; one
  bad video does not abort the batch.

  No video files are downloaded — playback uses the existing YouTube
  iframe in `tiqit_unlocked_content.ex` against the populated
  `youtube_id`.
  """

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Arcade, ContentGroup, ContentPiece}
  alias Qlarius.Tiqit.Arcade.Creators
  alias Qlarius.Youtube.Client
  alias QlariusWeb.Uploaders.CreatorImage

  require Logger

  @doc false
  def fetch_channel_preview(input), do: fetch_import_preview(input)

  @doc """
  Look up a channel or playlist and return a preview for the wizard.

  Returns `{:ok, %{channel_preview: preview, videos: [video_attrs]}}`.
  Each video map includes `:playlist_position` (0-based index in source
  list) so `import_into_group/3` can assign `display_order` in that order.

  `channel_preview` is a map with at least `:title`, `:description`,
  `:thumbnail_url`, and `:import_kind` (`:channel` | `:playlist`). For
  channels, `channel_id` and `uploads_playlist_id` are present; for
  playlists, `playlist_id` is present.
  """
  def fetch_import_preview(input) do
    case Client.parse_import_input(input) do
      {:error, reason} ->
        {:error, reason}

      {:playlist, playlist_id} ->
        with {:ok, playlist} <- Client.fetch_playlist(playlist_id),
             {:ok, items} <- Client.list_all_uploads(playlist_id),
             items <- Enum.sort_by(items, & &1.playlist_position),
             video_ids <- Enum.map(items, & &1.youtube_id),
             {:ok, details_by_id} <- Client.video_details(video_ids) do
          videos = Enum.map(items, &video_attrs_from_item(&1, details_by_id))

          preview =
            playlist
            |> Map.put(:import_kind, :playlist)

          {:ok, %{channel_preview: preview, videos: videos}}
        end

      {:channel, channel_input} ->
        with {:ok, channel} <- Client.resolve_channel(channel_input),
             {:ok, items} <- Client.list_all_uploads(channel.uploads_playlist_id),
             video_ids <- Enum.map(items, & &1.youtube_id),
             {:ok, details_by_id} <- Client.video_details(video_ids) do
          videos =
            items
            |> Enum.with_index()
            |> Enum.map(fn {item, idx} ->
              item
              |> Map.put(:playlist_position, idx)
              |> video_attrs_from_item(details_by_id)
            end)

          preview = Map.put(channel, :import_kind, :channel)

          {:ok, %{channel_preview: preview, videos: videos}}
        end
    end
  end

  defp video_attrs_from_item(item, details_by_id) do
    details = Map.get(details_by_id, item.youtube_id, %{})

    %{
      youtube_id: item.youtube_id,
      title: item.title,
      description: details[:description] || item.description,
      length: details[:duration_seconds] || 0,
      date_published: parse_published_date(item.published_at),
      thumbnail_url: item.thumbnail_url,
      playlist_position: item.playlist_position
    }
  end

  @doc """
  Import the selected videos as `ContentPiece`s under an existing
  `%ContentGroup{}`. The group must be preloaded with `:catalog`
  (needed for `CreatorImage` storage path resolution).

  Arguments:

    * `content_group` — pre-loaded `%ContentGroup{catalog: %Catalog{}}`.
    * `videos` — list of normalized video maps from
      `fetch_import_preview/1` (only the ones the user selected), ordered
      for import by ascending `:playlist_position`.
    * `opts` — `:on_progress` (1-arity fn called after each piece with
      a 1-based index).

  Returns `{:ok, [%{video: video, status: status}]}` where `status` is
  `:ok` or `{:error, reason}`. One bad video does not abort the batch.
  """
  def import_into_group(%ContentGroup{} = content_group, videos, opts \\ []) do
    on_progress = Keyword.get(opts, :on_progress, fn _idx -> :ok end)
    group = ensure_catalog_preloaded(content_group)

    base_order = Creators.next_content_piece_display_order(group)

    ordered_videos =
      videos
      |> Enum.sort_by(&(&1[:playlist_position] || 0))

    results =
      ordered_videos
      |> Enum.with_index()
      |> Enum.map(fn {video, idx} ->
        status = import_one_piece(group, video, base_order + idx)
        on_progress.(idx + 1)
        %{video: video, status: status}
      end)

    {:ok, results}
  end

  # ----- internals -----

  defp ensure_catalog_preloaded(%ContentGroup{catalog: %Qlarius.Tiqit.Arcade.Catalog{}} = group),
    do: group

  defp ensure_catalog_preloaded(%ContentGroup{} = group),
    do: Repo.preload(group, :catalog)

  defp import_one_piece(%ContentGroup{} = group, video, display_order) do
    try do
      with {:ok, image_filename} <- store_thumbnail(group, video),
           {:ok, piece} <- insert_piece(group, video, image_filename, display_order) do
        Arcade.write_default_piece_tiqit_classes(piece)
        :ok
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, format_changeset_error(changeset)}

        {:error, reason} when is_binary(reason) ->
          {:error, reason}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
    rescue
      e ->
        Logger.error("YouTube import piece failed: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  defp store_thumbnail(%ContentGroup{}, %{thumbnail_url: nil}), do: {:ok, nil}
  defp store_thumbnail(%ContentGroup{}, %{thumbnail_url: ""}), do: {:ok, nil}

  defp store_thumbnail(%ContentGroup{} = group, %{thumbnail_url: url, youtube_id: yt_id}) do
    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        ext = thumbnail_extension(url)
        tmp_path = Path.join(System.tmp_dir!(), "yt-#{yt_id}-#{:rand.uniform(1_000_000)}#{ext}")
        File.write!(tmp_path, body)

        upload = %Plug.Upload{
          path: tmp_path,
          filename: "yt-#{yt_id}#{ext}",
          content_type: "image/jpeg"
        }

        result = CreatorImage.store({upload, group})
        File.rm(tmp_path)

        case result do
          {:ok, filename} -> {:ok, filename}
          other -> {:error, "Failed to store thumbnail: #{inspect(other)}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "Thumbnail download failed (#{status})"}

      {:error, exception} ->
        {:error, "Thumbnail download error: #{Exception.message(exception)}"}
    end
  end

  defp thumbnail_extension(url) do
    case Path.extname(URI.parse(url).path || "") do
      "" -> ".jpg"
      ext -> ext
    end
  end

  defp insert_piece(%ContentGroup{} = group, video, image_filename, display_order) do
    attrs = %{
      title: video.title,
      description: video.description,
      date_published: video.date_published,
      length: video.length,
      image: image_filename,
      youtube_id: video.youtube_id,
      display_order: display_order,
      source_provider: "youtube",
      source_url: "https://www.youtube.com/watch?v=#{video.youtube_id}",
      source_imported_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %ContentPiece{content_group_id: group.id, content_group: group}
    |> ContentPiece.import_changeset(attrs)
    |> Repo.insert()
  end

  defp parse_published_date(nil), do: nil

  defp parse_published_date(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.to_date(dt)
      _ -> nil
    end
  end

  defp format_changeset_error(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
    |> Enum.join(", ")
  end
end
