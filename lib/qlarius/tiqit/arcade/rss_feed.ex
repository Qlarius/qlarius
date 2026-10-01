defmodule Qlarius.Tiqit.Arcade.RssFeed do
  @moduledoc """
  Fetches and parses a podcast RSS feed into plain maps.

  Only feed XML is read; web pages are never scraped. DTDs are not loaded,
  so external entities in a feed are ignored.
  """

  import SweetXml, only: [sigil_x: 2, xpath: 2, add_namespace: 3]

  alias Qlarius.Tiqit.Arcade.ImportHttp

  @itunes "http://www.itunes.com/dtds/podcast-1.0.dtd"
  @content "http://purl.org/rss/1.0/modules/content/"
  @months ~w(jan feb mar apr may jun jul aug sep oct nov dec)

  @doc """
  Fetches the feed over https and parses it.
  """
  def fetch(url) do
    with {:ok, %{body: body}} <- ImportHttp.get(url, schemes: ["https"]) do
      parse(body)
    end
  end

  @doc """
  Parses feed XML. Returns `{:ok, %{channel: map, items: [map]}}` or
  `{:error, message}`.
  """
  def parse(xml) when is_binary(xml) do
    doc = SweetXml.parse(xml, dtd: :none, quiet: true, namespace_conformant: true)

    case xpath(doc, ~x"/rss/channel"o) do
      nil ->
        {:error, "Not an RSS feed"}

      channel ->
        {:ok, %{channel: channel_map(channel), items: Enum.map(items(channel), &item_map/1)}}
    end
  rescue
    _ -> {:error, "Feed XML could not be read"}
  catch
    :exit, _ -> {:error, "Feed XML could not be read"}
  end

  def parse(_), do: {:error, "Feed XML could not be read"}

  @doc """
  Seasons in the feed, newest first, with counts and a sample title.
  Items without a season are grouped under `nil`.
  """
  def seasons(items) do
    items
    |> Enum.group_by(& &1.season)
    |> Enum.map(fn {season, season_items} ->
      sorted = Enum.sort_by(season_items, &sort_key/1)

      %{
        season: season,
        count: length(season_items),
        episode_types: season_items |> Enum.map(& &1.episode_type) |> Enum.frequencies(),
        first_title: sorted |> List.first() |> Map.get(:title),
        first_published: sorted |> List.first() |> Map.get(:date_published)
      }
    end)
    |> Enum.sort_by(&(&1.season || -1), :desc)
  end

  @doc """
  Oldest first. Items published the same day keep episode-number order.
  """
  def sort_key(item) do
    {time_sort(item), item.episode_number || 0, item.title || ""}
  end

  defp time_sort(%{published_at: %DateTime{} = at}), do: DateTime.to_iso8601(at)
  defp time_sort(%{date_published: %Date{} = date}), do: "#{Date.to_iso8601(date)}T00:00:00Z"
  defp time_sort(_), do: "9999"

  defp items(channel), do: xpath(channel, ~x"./item"l)

  defp channel_map(channel) do
    %{
      title: text(channel, ~x"./title/text()"s),
      description: channel |> text(~x"./description/text()"ls) |> strip_html(),
      link: text(channel, ~x"./link/text()"s),
      image_url:
        first_present([
          text(channel, ns(~x"./itunes:image/@href"s)),
          text(channel, ~x"./image/url/text()"s)
        ]),
      author: text(channel, ns(~x"./itunes:author/text()"s))
    }
  end

  defp item_map(item) do
    guid = text(item, ~x"./guid/text()"s)
    enclosure_url = text(item, ~x"./enclosure/@url"s)
    pub_date = text(item, ~x"./pubDate/text()"s)

    %{
      guid: first_present([guid, enclosure_url]),
      title: text(item, ~x"./title/text()"s),
      description:
        first_present([
          text(item, ~x"./description/text()"ls),
          text(item, ns(~x"./itunes:summary/text()"ls)),
          text(item, ns(~x"./content:encoded/text()"ls))
        ])
        |> strip_html(),
      date_published: parse_date(pub_date),
      published_at: parse_datetime(pub_date),
      enclosure_url: enclosure_url,
      enclosure_type: text(item, ~x"./enclosure/@type"s),
      length_seconds: item |> text(ns(~x"./itunes:duration/text()"s)) |> parse_duration(),
      season: item |> text(ns(~x"./itunes:season/text()"s)) |> to_integer(),
      episode_number: item |> text(ns(~x"./itunes:episode/text()"s)) |> to_integer(),
      episode_type: item |> text(ns(~x"./itunes:episodeType/text()"s)) |> episode_type(),
      image_url: text(item, ns(~x"./itunes:image/@href"s)),
      link: text(item, ~x"./link/text()"s)
    }
  end

  defp ns(path) do
    path
    |> add_namespace("itunes", @itunes)
    |> add_namespace("content", @content)
  end

  defp text(node, path) do
    case xpath(node, path) do
      values when is_list(values) ->
        values |> Enum.join() |> blank_to_nil()

      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end

      _ ->
        nil
    end
  end

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp first_present(values), do: Enum.find(values, &(is_binary(&1) and &1 != ""))

  defp episode_type(nil), do: "full"

  defp episode_type(value) do
    value = String.downcase(value)
    if value in ~w(full trailer bonus), do: value, else: "full"
  end

  @doc """
  Reads `itunes:duration` as seconds (`3069`, `51:09`, or `00:51:09`).
  """
  def parse_duration(nil), do: nil

  def parse_duration(value) when is_binary(value) do
    parts = value |> String.trim() |> String.split(":")

    if parts != [] and Enum.all?(parts, &Regex.match?(~r/^\d+(\.\d+)?$/, &1)) do
      parts
      |> Enum.map(&(&1 |> Float.parse() |> elem(0)))
      |> Enum.reduce(0, fn part, acc -> acc * 60 + part end)
      |> trunc()
    end
  end

  @doc """
  Reads an RFC 822 `pubDate` (`Tue, 19 Mar 2024 09:00:02 +0000`) as a date.
  """
  def parse_date(nil), do: nil

  def parse_date(value) when is_binary(value) do
    with [_, day, month, year] <- Regex.run(~r/(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})/, value),
         index when is_integer(index) <-
           Enum.find_index(@months, &(&1 == String.downcase(month))),
         {:ok, date} <-
           Date.new(String.to_integer(year), index + 1, String.to_integer(day)) do
      date
    else
      _ ->
        case Date.from_iso8601(String.slice(value, 0, 10)) do
          {:ok, date} -> date
          _ -> nil
        end
    end
  end

  @zone_offsets %{
    "EST" => -5,
    "EDT" => -4,
    "CST" => -6,
    "CDT" => -5,
    "MST" => -7,
    "MDT" => -6,
    "PST" => -8,
    "PDT" => -7
  }

  @doc """
  Reads a `pubDate` as a UTC `DateTime`, keeping the time of day so items
  published the same day keep their order. Returns nil when there is no time.
  """
  def parse_datetime(nil), do: nil

  def parse_datetime(value) when is_binary(value) do
    regex =
      ~r/(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]+)?/

    with [_, day, month, year, hour, minute | rest] <- Regex.run(regex, value),
         index when is_integer(index) <-
           Enum.find_index(@months, &(&1 == String.downcase(month))),
         {:ok, date} <- Date.new(String.to_integer(year), index + 1, String.to_integer(day)),
         {:ok, time} <-
           Time.new(String.to_integer(hour), String.to_integer(minute), seconds(rest)),
         {:ok, naive} <- NaiveDateTime.new(date, time) do
      naive
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(-offset_seconds(Enum.at(rest, 1)), :second)
    else
      _ ->
        case DateTime.from_iso8601(value) do
          {:ok, at, _offset} -> DateTime.truncate(at, :second)
          _ -> nil
        end
    end
  end

  defp seconds([sec | _]) when sec not in [nil, ""], do: String.to_integer(sec)
  defp seconds(_), do: 0

  defp offset_seconds(<<sign, hh::binary-size(2), mm::binary-size(2)>>) when sign in [?+, ?-] do
    total = String.to_integer(hh) * 3600 + String.to_integer(mm) * 60
    if sign == ?-, do: -total, else: total
  end

  defp offset_seconds(zone) when is_binary(zone),
    do: Map.get(@zone_offsets, String.upcase(zone), 0) * 3600

  defp offset_seconds(_), do: 0

  defp to_integer(nil), do: nil

  defp to_integer(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp strip_html(nil), do: nil

  defp strip_html(html) do
    html
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<\/p>/i, "\n\n")
    |> Floki.parse_fragment()
    |> case do
      {:ok, nodes} -> Floki.text(nodes)
      _ -> html
    end
    |> String.replace(~r/[ \t]+\n/, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
