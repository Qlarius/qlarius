defmodule Qlarius.Tiqit.Arcade.RssImporterTest do
  use Qlarius.DataCase, async: false

  import Ecto.Query
  import Qlarius.ContentImportHelpers

  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{ContentGroup, ContentPiece, RssImporter}

  setup do
    stub_feed()
    %{catalog: podcast_catalog_fixture()}
  end

  test "imports one season's full episodes and trailer, oldest first", %{catalog: catalog} do
    assert {:ok, detail} =
             RssImporter.import_feed(%{
               "feed_url" => feed_url(),
               "catalog_id" => catalog.id,
               "season" => 3,
               "group_title" => "Season Three"
             })

    assert detail.counts == %{created: 3, updated: 0, unchanged: 0, skipped: 0}
    assert Enum.any?(detail.warnings, &(&1 =~ "Episode 3: The Appeal"))

    group = Repo.get!(ContentGroup, detail.content_group.id)
    assert group.title == "Season Three"
    assert group.source_provider == "rss"
    assert group.feed_url == feed_url()
    assert group.feed_season == 3
    assert group.feed_episode_types == ["full", "trailer"]
    assert group.last_synced_at

    pieces = pieces(group)

    assert Enum.map(pieces, & &1.title) == [
             "Trailer",
             "Episode 1: The Crime",
             "Episode 2: The Trial"
           ]

    [_trailer, episode | _] = pieces
    assert episode.media_type == "audio"
    assert episode.file_url == "https://audio.example.com/s3-e1.mp3"
    assert episode.external_id == "tm-s3-e1"
    assert episode.youtube_id == nil
    assert episode.length == 3069
    assert episode.episode_number == 1
    assert episode.source_provider == "rss"
  end

  test "imports URL guids with artwork, and a repeat sync adds nothing", %{catalog: catalog} do
    uploads = use_tmp_uploads()

    feed_url_guids()
    |> stub_feed(images: true)

    assert {:ok, detail} =
             RssImporter.import_feed(%{
               "feed_url" => feed_url(),
               "catalog_id" => catalog.id,
               "season" => 3,
               "group_title" => "Shane and Sally"
             })

    assert detail.counts.created == 3
    assert detail.warnings |> Enum.reject(&(&1 =~ "Episode 3")) == []

    group = Repo.get!(ContentGroup, detail.content_group.id)
    assert group.image

    pieces = pieces(group)

    assert Enum.map(pieces, & &1.external_id) == [
             "https://api.spreaker.com/episode/tm-s3-trailer",
             "https://api.spreaker.com/episode/tm-s3-e1",
             "https://api.spreaker.com/episode/tm-s3-e2"
           ]

    assert [nil, e1_image, nil] = Enum.map(pieces, & &1.image)
    refute String.contains?(e1_image, ["/", ":"])
    assert uploads |> Path.join("**/*.jpg") |> Path.wildcard() |> length() == 2

    assert {:ok, synced} = RssImporter.sync_group(group)
    assert synced.counts.created == 0
    assert length(pieces(group)) == 3
  end

  describe "episode numbers" do
    test "keeps consecutive feed numbers, including ones that don't start at 1" do
      items = [item("a", 1), item("b", 2), item("t", nil, "trailer"), item("c", 3)]
      assert {^items, []} = RssImporter.number_episodes(items)

      items = [item("a", 101), item("b", 102)]
      assert {^items, []} = RssImporter.number_episodes(items)
    end

    test "renumbers a season with gaps, repeats, or missing numbers" do
      items = [
        item("t", nil, "trailer"),
        item("a", nil),
        item("b", 2),
        item("c", 3),
        item("d", 3),
        item("x", 9, "bonus")
      ]

      assert {numbered, [nil]} = RssImporter.number_episodes(items)
      assert Enum.map(numbered, & &1.episode_number) == [nil, 1, 2, 3, 4, 9]
    end

    test "numbers each season on its own" do
      items = [
        item("a", 1, "full", 1),
        item("b", 2, "full", 1),
        item("c", 5, "full", 2),
        item("d", 7, "full", 2)
      ]

      assert {numbered, [2]} = RssImporter.number_episodes(items)
      assert Enum.map(numbered, & &1.episode_number) == [1, 2, 1, 2]
    end
  end

  test "a same-day feed with messy numbers imports in publish order", %{catalog: catalog} do
    stub_feed(same_day_feed())

    assert {:ok, preview} = RssImporter.preview(feed_url())
    assert preview.renumbered_seasons == [nil]

    assert Enum.map(preview.items, &{&1.title, &1.episode_number, &1.feed_episode_number}) == [
             {"Trailer", nil, nil},
             {"A Long, Hot Summer", 1, nil},
             {"Lost Horizons", 2, 2},
             {"The Man on the Moon", 3, 5},
             {"The Edge of Town", 4, 3}
           ]

    assert {:ok, detail} =
             RssImporter.import_feed(%{"feed_url" => feed_url(), "catalog_id" => catalog.id})

    assert Enum.any?(detail.warnings, &(&1 =~ "numbered by publish order"))

    group = Repo.get!(ContentGroup, detail.content_group.id)

    assert group |> pieces() |> Enum.map(&{&1.title, &1.episode_number}) == [
             {"Trailer", nil},
             {"A Long, Hot Summer", 1},
             {"Lost Horizons", 2},
             {"The Man on the Moon", 3},
             {"The Edge of Town", 4}
           ]
  end

  test "reorder_by_episode renumbers from the feed and fixes the order", %{catalog: catalog} do
    stub_feed(same_day_feed())

    {:ok, detail} =
      RssImporter.import_feed(%{"feed_url" => feed_url(), "catalog_id" => catalog.id})

    group = Repo.get!(ContentGroup, detail.content_group.id)
    [trailer, first | rest] = pieces(group)

    Repo.update_all(from(p in ContentPiece, where: p.id == ^trailer.id), set: [display_order: 99])
    Repo.update_all(from(p in ContentPiece, where: p.id == ^first.id), set: [episode_number: nil])
    assert hd(pieces(group)).id == first.id

    assert {:ok, %{counts: %{updated: 1}}} = RssImporter.reorder_by_episode(group)
    assert Enum.map(pieces(group), & &1.id) == [trailer.id, first.id | Enum.map(rest, & &1.id)]
    assert Repo.get!(ContentPiece, first.id).episode_number == 1
  end

  test "two groups for one creator keep their own artwork", %{catalog: catalog} do
    use_tmp_uploads()
    stub_feed(nil, images: true)

    {:ok, first} =
      RssImporter.import_feed(%{
        "feed_url" => feed_url(),
        "catalog_id" => catalog.id,
        "season" => 3
      })

    {:ok, second} =
      RssImporter.import_feed(%{
        "feed_url" => feed_url(),
        "catalog_id" => catalog.id,
        "season" => 2
      })

    first_image = Repo.get!(ContentGroup, first.content_group.id).image
    second_image = Repo.get!(ContentGroup, second.content_group.id).image
    assert first_image && second_image
    refute first_image == second_image
  end

  test "episode art is kept only when it is unique to the episode" do
    feed = %{
      channel: %{image_url: "https://cdn.example.com/show.jpg"},
      items: [
        %{guid: "own", image_url: "https://cdn.example.com/own.jpg"},
        %{guid: "channel", image_url: "https://CDN.example.com/show.jpg?size=3000"},
        %{guid: "shared-1", image_url: "https://cdn.example.com/season.jpg"},
        %{guid: "shared-2", image_url: "https://cdn.example.com/season.jpg?v=2"},
        %{guid: "none", image_url: nil}
      ]
    }

    assert RssImporter.episode_art(feed) == %{"own" => "https://cdn.example.com/own.jpg"}
  end

  test "a dry run writes nothing", %{catalog: catalog} do
    assert {:ok, %{dry_run: true, counts: %{created: 3}}} =
             RssImporter.import_feed(%{
               "feed_url" => feed_url(),
               "catalog_id" => catalog.id,
               "season" => "3",
               "dry_run" => true
             })

    assert Repo.aggregate(from(g in ContentGroup, where: g.catalog_id == ^catalog.id), :count) ==
             0
  end

  test "sync adds new guids and keeps hand-edited titles", %{catalog: catalog} do
    {:ok, detail} =
      RssImporter.import_feed(%{
        "feed_url" => feed_url(),
        "catalog_id" => catalog.id,
        "season" => 3,
        "guids" => ["tm-s3-trailer", "tm-s3-e1"]
      })

    assert detail.counts.created == 2
    group = Repo.get!(ContentGroup, detail.content_group.id)

    trailer = Enum.find(pieces(group), &(&1.external_id == "tm-s3-trailer"))
    trailer |> Ecto.Changeset.change(title: "Official trailer") |> Repo.update!()

    assert {:ok, synced} = RssImporter.sync_group(group)
    assert synced.counts.created == 1
    assert synced.counts.updated == 0

    titles = group |> pieces() |> Enum.map(& &1.title)
    assert titles == ["Official trailer", "Episode 1: The Crime", "Episode 2: The Trial"]

    assert {:ok, again} = RssImporter.sync_group(Repo.get!(ContentGroup, group.id))
    assert again.counts.created == 0
  end

  test "sync needs a stored feed", %{catalog: catalog} do
    assert {:error, :no_feed_url} = RssImporter.sync_group(content_group_fixture(catalog))
  end

  test "rejects bad input", %{catalog: catalog} do
    assert {:error, :feed_url_required} = RssImporter.import_feed(%{"catalog_id" => catalog.id})

    assert {:error, :invalid_season} =
             RssImporter.import_feed(%{"feed_url" => feed_url(), "season" => "three"})

    assert {:error, :invalid_episode_types} =
             RssImporter.import_feed(%{"feed_url" => feed_url(), "episode_types" => ["movie"]})
  end

  test "auto_sync_groups lists only groups with daily sync on", %{catalog: catalog} do
    {:ok, detail} =
      RssImporter.import_feed(%{
        "feed_url" => feed_url(),
        "catalog_id" => catalog.id,
        "season" => 3,
        "auto_sync" => true
      })

    ids = Enum.map(RssImporter.auto_sync_groups(), & &1.id)
    assert detail.content_group.id in ids

    group = Repo.get!(ContentGroup, detail.content_group.id)
    {:ok, _} = RssImporter.set_auto_sync(group, false)
    refute detail.content_group.id in Enum.map(RssImporter.auto_sync_groups(), & &1.id)
  end

  defp item(guid, number, type \\ "full", season \\ nil) do
    %{guid: guid, episode_number: number, episode_type: type, season: season}
  end

  defp same_day_feed do
    items =
      [
        {"09:40", "The Edge of Town", 3, "full"},
        {"09:30", "The Man on the Moon", 5, "full"},
        {"09:10", "Lost Horizons", 2, "full"},
        {"09:05", "A Long, Hot Summer", nil, "full"},
        {"09:00", "Trailer", nil, "trailer"}
      ]
      |> Enum.map_join("\n", fn {time, title, number, type} ->
        episode = if number, do: "<itunes:episode>#{number}</itunes:episode>", else: ""
        slug = title |> String.downcase() |> String.replace(~r/[^a-z]+/, "-")

        """
        <item>
          <title>#{title}</title>
          <guid isPermaLink="false">https://api.spreaker.com/episode/#{slug}</guid>
          <pubDate>Tue, 18 Jun 2024 #{time}:00 +0000</pubDate>
          <enclosure url="https://audio.example.com/#{slug}.mp3" type="audio/mpeg"/>
          <itunes:episodeType>#{type}</itunes:episodeType>
          #{episode}
        </item>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel><title>Shane and Sally</title>#{items}</channel>
    </rss>
    """
  end

  defp feed_url_guids do
    Regex.replace(
      ~r{<guid isPermaLink="false">([^<]+)</guid>},
      feed_xml(),
      ~s(<guid isPermaLink="true">https://api.spreaker.com/episode/\\1</guid>)
    )
  end

  defp pieces(group) do
    Repo.all(
      from p in ContentPiece,
        where: p.content_group_id == ^group.id,
        order_by: [asc: p.display_order, asc: p.id]
    )
  end
end
