defmodule Qlarius.Tiqit.Arcade.RssFeedTest do
  use ExUnit.Case, async: true

  alias Qlarius.ContentImportHelpers
  alias Qlarius.Tiqit.Arcade.RssFeed

  setup do
    {:ok, feed} = RssFeed.parse(ContentImportHelpers.feed_xml())
    %{feed: feed}
  end

  test "reads the channel", %{feed: feed} do
    assert feed.channel.title == "Texas Monthly True Crime"
    assert feed.channel.description == "True stories from Texas."
    assert feed.channel.image_url == "https://cdn.example.com/show.jpg"
    assert feed.channel.author == "Texas Monthly"
  end

  test "reads item fields", %{feed: feed} do
    episode = Enum.find(feed.items, &(&1.guid == "tm-s3-e1"))

    assert episode.title == "Episode 1: The Crime"
    assert episode.description =~ "Where it began."
    assert episode.description =~ "Part one."
    refute episode.description =~ "<p>"
    assert episode.date_published == ~D[2024-04-03]
    assert episode.enclosure_url == "https://audio.example.com/s3-e1.mp3"
    assert episode.enclosure_type == "audio/mpeg"
    assert episode.length_seconds == 51 * 60 + 9
    assert episode.season == 3
    assert episode.episode_number == 1
    assert episode.episode_type == "full"
    assert episode.image_url == "https://cdn.example.com/s3-e1.jpg"
    assert episode.link == "https://www.texasmonthly.com/podcasts/episode-1/"
  end

  test "defaults a missing episode type to full", %{feed: feed} do
    assert Enum.find(feed.items, &(&1.guid == "tm-s2-e1")).episode_type == "full"
  end

  test "reads every duration format" do
    assert RssFeed.parse_duration("3069") == 3069
    assert RssFeed.parse_duration("51:09") == 3069
    assert RssFeed.parse_duration("00:51:09") == 3069
    assert RssFeed.parse_duration("2:30") == 150
    assert RssFeed.parse_duration("soon") == nil
  end

  test "reads RFC 822 and ISO dates" do
    assert RssFeed.parse_date("Tue, 19 Mar 2024 09:00:02 +0000") == ~D[2024-03-19]
    assert RssFeed.parse_date("2024-03-19T09:00:00Z") == ~D[2024-03-19]
    assert RssFeed.parse_date("someday") == nil
  end

  test "keeps the publish time, in UTC" do
    assert RssFeed.parse_datetime("Tue, 18 Jun 2024 09:05:01 +0000") == ~U[2024-06-18 09:05:01Z]
    assert RssFeed.parse_datetime("Tue, 18 Jun 2024 04:05:01 -0500") == ~U[2024-06-18 09:05:01Z]
    assert RssFeed.parse_datetime("Tue, 18 Jun 2024 09:05 GMT") == ~U[2024-06-18 09:05:00Z]
    assert RssFeed.parse_datetime("Tue, 18 Jun 2024 02:05:01 PDT") == ~U[2024-06-18 09:05:01Z]
    assert RssFeed.parse_datetime("2024-06-18T09:05:01Z") == ~U[2024-06-18 09:05:01Z]
    assert RssFeed.parse_datetime("Tue, 18 Jun 2024") == nil
  end

  test "items published the same day sort by time, not episode number" do
    later = %{
      published_at: ~U[2024-06-18 09:10:00Z],
      date_published: ~D[2024-06-18],
      episode_number: 1,
      title: "A"
    }

    earlier = %{later | published_at: ~U[2024-06-18 09:00:00Z], episode_number: nil, title: "Z"}

    assert Enum.sort_by([later, earlier], &RssFeed.sort_key/1) == [earlier, later]
  end

  test "lists seasons newest first", %{feed: feed} do
    assert [%{season: 3, count: 5} = s3, %{season: 2, count: 1}] = RssFeed.seasons(feed.items)
    assert s3.first_title == "Trailer"
    assert s3.episode_types == %{"bonus" => 1, "full" => 3, "trailer" => 1}
  end

  test "refuses documents that are not RSS" do
    assert {:error, "Not an RSS feed"} = RssFeed.parse("<html><body>hi</body></html>")
    assert {:error, _} = RssFeed.parse("not xml at all <")
  end
end
