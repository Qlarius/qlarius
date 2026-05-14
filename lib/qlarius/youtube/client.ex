defmodule Qlarius.Youtube.Client do
  @moduledoc """
  Minimal client for the YouTube Data API v3 used by the Tiqit Arcade
  import wizard.

  Call sites for channel or playlist import:

    1. `parse_import_input/1` — classify pasted text as `{:playlist, id}`
       (from `?list=…`, `/playlist?list=…`, or a bare playlist id) or
       `{:channel, input}` for everything else.

    2. `resolve_channel/1` — `@handle`, channel URL, or channel ID →
       canonical channel + **uploads** playlist id (cheap full catalog).

    3. `fetch_playlist/1` — playlist id → title, description, thumbnail
       via `playlists.list`.

    4. `list_all_uploads/2` — page `playlistItems` for **any** playlist id
       (uploads playlist or user playlist; same 1 quota unit per page).

    5. `video_details/1` — batch `videos.list` for durations and full
       descriptions.

  All calls require an API key configured under `:qlarius, :youtube,
  api_key: ...` (see `config/runtime.exs`).
  """

  @base_url "https://www.googleapis.com/youtube/v3"

  # Defensive ceiling — purely a runaway-loop guard, not a product cap.
  # YouTube's max page size is 50, so this lets us walk up to 100 pages
  # / 5,000 videos before we bail out and log a warning.
  @max_upload_pages 100
  # Max ids per `videos.list?id=...` call (YouTube API limit).
  @video_details_chunk 50

  @doc """
  Classify import input as a **playlist** (returns playlist id) or
  **channel** (returns the original string for `resolve_channel/1`).

  Playlists are detected when:

    * the string contains `list=<id>` (e.g. watch URLs or embed URLs), or
    * it is a bare playlist id (alphanumeric, length ≥ 12, not a `UC…`
      channel id).

  Otherwise returns `{:channel, trimmed}` so existing channel resolution
  applies (`@handle`, `/channel/…`, `/c/…`, `/user/…`, `/\@…`, etc.).
  """
  def parse_import_input(input) when is_binary(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" ->
        {:error, "Input is blank"}

      id = extract_playlist_id(trimmed) ->
        {:playlist, id}

      true ->
        {:channel, trimmed}
    end
  end

  @doc """
  Fetch playlist metadata via `playlists.list`.

  Returns `{:ok, %{playlist_id, title, description, thumbnail_url}}`.
  """
  def fetch_playlist(playlist_id) when is_binary(playlist_id) do
    params = [part: "snippet,contentDetails", id: playlist_id, key: api_key!()]

    case Req.get(@base_url <> "/playlists", params: params) do
      {:ok, %Req.Response{status: 200, body: %{"items" => [item | _]}}} ->
        {:ok, normalize_playlist(item, playlist_id)}

      {:ok, %Req.Response{status: 200, body: %{"items" => []}}} ->
        {:error, "Playlist not found"}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, api_error(status, body)}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  @doc """
  Resolve a channel from a handle (`@name`), full URL, or raw channel id.

  Returns `{:ok, %{channel_id, title, description, thumbnail_url,
  uploads_playlist_id}}` on success, or `{:error, reason}` on any API or
  network failure.
  """
  def resolve_channel(input) when is_binary(input) do
    case parse_channel_input(input) do
      {:id, channel_id} -> fetch_channel(:id, channel_id)
      {:handle, handle} -> fetch_channel(:handle, handle)
      {:username, username} -> fetch_channel(:username, username)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List every video in a channel's uploads playlist, walking
  `nextPageToken` until exhausted. Each page costs 1 quota unit.

  Stops at `@max_upload_pages` (defensive runaway guard, not a product
  cap) and logs a warning if reached. Returns whatever it has collected
  so far in that case.
  """
  def list_all_uploads(uploads_playlist_id, opts \\ [])
      when is_binary(uploads_playlist_id) do
    do_list_uploads(uploads_playlist_id, nil, [], 0, opts)
  end

  defp do_list_uploads(_playlist_id, _token, acc, page_count, _opts)
       when page_count >= @max_upload_pages do
    require Logger

    Logger.warning(
      "Qlarius.Youtube.Client: hit @max_upload_pages (#{@max_upload_pages}) — returning partial set of #{length(acc)} videos"
    )

    {:ok, Enum.reverse(acc)}
  end

  defp do_list_uploads(playlist_id, page_token, acc, page_count, opts) do
    params =
      [
        part: "snippet,contentDetails",
        playlistId: playlist_id,
        maxResults: 50,
        key: api_key!()
      ]
      |> maybe_put(:pageToken, page_token)

    case Req.get(@base_url <> "/playlistItems", params: params) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        items =
          body["items"]
          |> List.wrap()
          |> Enum.map(&normalize_playlist_item/1)
          |> Enum.reject(&is_nil/1)

        new_acc = Enum.reduce(items, acc, &[&1 | &2])

        case body["nextPageToken"] do
          nil -> {:ok, Enum.reverse(new_acc)}
          token -> do_list_uploads(playlist_id, token, new_acc, page_count + 1, opts)
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, api_error(status, body)}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)

  @doc """
  Batch-fetch ISO-8601 durations and full snippets for any number of
  video ids. Automatically chunks into 50-id calls (the API per-call
  max). Returns a map keyed by `youtube_id`.
  """
  def video_details([]), do: {:ok, %{}}

  def video_details(youtube_ids) when is_list(youtube_ids) do
    youtube_ids
    |> Enum.chunk_every(@video_details_chunk)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      case fetch_video_details_chunk(chunk) do
        {:ok, chunk_map} -> {:cont, {:ok, Map.merge(acc, chunk_map)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp fetch_video_details_chunk(ids) do
    params = [
      part: "contentDetails,snippet",
      id: Enum.join(ids, ","),
      key: api_key!()
    ]

    case Req.get(@base_url <> "/videos", params: params) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        details =
          (body["items"] || [])
          |> Enum.map(&normalize_video_details/1)
          |> Map.new(&{&1.youtube_id, &1})

        {:ok, details}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, api_error(status, body)}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  @doc """
  Parse an ISO-8601 duration string (e.g. `"PT1H2M3S"`) into total
  seconds. Returns `0` for unrecognized input.
  """
  def parse_iso8601_duration(nil), do: 0

  def parse_iso8601_duration(duration) when is_binary(duration) do
    regex = ~r/^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/

    case Regex.run(regex, duration) do
      [_ | parts] ->
        [h, m, s] =
          Enum.map(parts ++ List.duplicate(nil, 3 - length(parts)), fn
            nil -> 0
            "" -> 0
            n -> String.to_integer(n)
          end)

        h * 3600 + m * 60 + s

      _ ->
        0
    end
  end

  # ----- internals -----

  defp parse_channel_input(input) do
    trimmed = String.trim(input)

    cond do
      trimmed == "" ->
        {:error, "Channel input is blank"}

      String.starts_with?(trimmed, "UC") and String.length(trimmed) == 24 ->
        {:id, trimmed}

      String.starts_with?(trimmed, "@") ->
        {:handle, String.trim_leading(trimmed, "@")}

      String.starts_with?(trimmed, "http") ->
        parse_channel_url(URI.parse(trimmed))

      true ->
        # Bare word — treat as a handle (most common public form today).
        {:handle, trimmed}
    end
  end

  defp parse_channel_url(%URI{path: nil}), do: {:error, "Could not parse channel URL"}

  defp parse_channel_url(%URI{path: path}) do
    segments =
      path
      |> String.split("/", trim: true)

    case segments do
      ["channel", id | _] -> {:id, id}
      ["@" <> handle | _] -> {:handle, handle}
      ["c", name | _] -> {:username, name}
      ["user", name | _] -> {:username, name}
      _ -> {:error, "Could not parse channel URL"}
    end
  end

  defp fetch_channel(kind, value) do
    base_params = [part: "snippet,contentDetails", key: api_key!()]

    extra =
      case kind do
        :id -> [id: value]
        :handle -> [forHandle: "@" <> value]
        :username -> [forUsername: value]
      end

    case Req.get(@base_url <> "/channels", params: base_params ++ extra) do
      {:ok, %Req.Response{status: 200, body: %{"items" => [item | _]}}} ->
        {:ok, normalize_channel(item)}

      {:ok, %Req.Response{status: 200, body: %{"items" => []}}} ->
        {:error, "Channel not found"}

      {:ok, %Req.Response{status: 200, body: _}} ->
        {:error, "Channel not found"}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, api_error(status, body)}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp normalize_channel(%{"id" => id, "snippet" => snippet, "contentDetails" => details}) do
    %{
      channel_id: id,
      title: snippet["title"],
      description: snippet["description"],
      thumbnail_url:
        get_in(snippet, ["thumbnails", "high", "url"]) ||
          get_in(snippet, ["thumbnails", "default", "url"]),
      uploads_playlist_id: get_in(details, ["relatedPlaylists", "uploads"])
    }
  end

  defp normalize_playlist(%{"snippet" => snippet}, playlist_id) do
    %{
      playlist_id: playlist_id,
      title: snippet["title"],
      description: snippet["description"] || "",
      thumbnail_url:
        get_in(snippet, ["thumbnails", "high", "url"]) ||
          get_in(snippet, ["thumbnails", "medium", "url"]) ||
          get_in(snippet, ["thumbnails", "default", "url"])
    }
  end

  defp normalize_playlist_item(%{
         "snippet" => snippet,
         "contentDetails" => %{"videoId" => video_id} = content
       }) do
    position =
      case snippet["position"] do
        n when is_integer(n) and n >= 0 ->
          n

        n when is_binary(n) ->
          case Integer.parse(n) do
            {i, _} when i >= 0 -> i
            _ -> 0
          end

        _ ->
          0
      end

    %{
      youtube_id: video_id,
      title: snippet["title"],
      description: snippet["description"],
      published_at: content["videoPublishedAt"] || snippet["publishedAt"],
      playlist_position: position,
      thumbnail_url:
        get_in(snippet, ["thumbnails", "maxres", "url"]) ||
          get_in(snippet, ["thumbnails", "high", "url"]) ||
          get_in(snippet, ["thumbnails", "default", "url"])
    }
  end

  defp normalize_playlist_item(_), do: nil

  defp normalize_video_details(%{"id" => id, "contentDetails" => details, "snippet" => snippet}) do
    %{
      youtube_id: id,
      duration_seconds: parse_iso8601_duration(details["duration"]),
      description: snippet["description"]
    }
  end

  defp extract_playlist_id(str) when is_binary(str) do
    cond do
      String.starts_with?(str, "http") ->
        uri = URI.parse(str)
        id_from_query(uri, "list") || id_from_playlist_path(uri)

      bare_playlist_id?(str) ->
        str

      true ->
        nil
    end
  end

  defp id_from_query(%URI{query: query}, key) when is_binary(query) do
    query
    |> URI.decode_query()
    |> Map.get(key)
    |> case do
      nil -> nil
      "" -> nil
      v when is_binary(v) -> if(valid_playlist_id?(v), do: v, else: nil)
    end
  end

  defp id_from_query(_, _), do: nil

  defp id_from_playlist_path(%URI{path: path} = uri) when is_binary(path) do
    segments = String.split(path, "/", trim: true)

    case segments do
      ["playlist" | _] -> id_from_query(uri, "list")
      _ -> nil
    end
  end

  defp id_from_playlist_path(_), do: nil

  defp bare_playlist_id?(str) when is_binary(str) do
    String.length(str) >= 12 and
      Regex.match?(~r/^[a-zA-Z0-9_-]+$/u, str) and
      not uc_channel_id?(str)
  end

  defp bare_playlist_id?(_), do: false

  defp uc_channel_id?(<<"UC", rest::binary>>) when byte_size(rest) == 22, do: true
  defp uc_channel_id?(_), do: false

  defp valid_playlist_id?(id) when is_binary(id) do
    String.length(id) >= 12 and Regex.match?(~r/^[a-zA-Z0-9_-]+$/u, id)
  end

  defp valid_playlist_id?(_), do: false

  defp api_error(status, %{"error" => %{"message" => message}}),
    do: "YouTube API #{status}: #{message}"

  defp api_error(status, _body), do: "YouTube API returned #{status}"

  defp api_key! do
    case Application.get_env(:qlarius, :youtube, [])[:api_key] do
      key when is_binary(key) and key != "" ->
        key

      _ ->
        raise "YOUTUBE_DATA_API_KEY is not configured. Set the env var and restart, or configure :qlarius, :youtube, api_key: ..."
    end
  end
end
