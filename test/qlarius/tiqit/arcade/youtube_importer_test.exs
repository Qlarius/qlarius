defmodule Qlarius.Tiqit.Arcade.YoutubeImporterTest do
  use ExUnit.Case, async: true

  alias Qlarius.Tiqit.Arcade.YoutubeImporter

  describe "published_date/2" do
    test "uses the date the video was published on YouTube" do
      assert YoutubeImporter.published_date(
               "2024-03-02T15:04:05Z",
               "2026-06-01T00:00:00Z"
             ) == ~D[2024-03-02]
    end

    test "falls back to the playlist item date when the video has none" do
      assert YoutubeImporter.published_date(nil, "2024-03-02T15:04:05Z") == ~D[2024-03-02]
    end

    test "returns nil when neither source has a date" do
      assert YoutubeImporter.published_date(nil, nil) == nil
    end
  end
end
