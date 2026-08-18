defmodule QlariusWeb.Creators.ContentGroupLive.YoutubeImportTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Creators.ContentGroupLive.YoutubeImport

  describe "parse_min_duration/1" do
    test "parses m:ss" do
      assert YoutubeImport.parse_min_duration("1:00") == 60
      assert YoutubeImport.parse_min_duration("1:30") == 90
      assert YoutubeImport.parse_min_duration("0:45") == 45
      assert YoutubeImport.parse_min_duration("1:5") == 65
    end

    test "treats a bare integer as minutes" do
      assert YoutubeImport.parse_min_duration("1") == 60
      assert YoutubeImport.parse_min_duration("2") == 120
    end

    test "treats blank and 0:00 as no minimum" do
      assert YoutubeImport.parse_min_duration("") == 0
      assert YoutubeImport.parse_min_duration("0:00") == 0
      assert YoutubeImport.parse_min_duration("1:") == 60
    end
  end

  describe "filtered_videos/3" do
    setup do
      videos = [
        %{youtube_id: "short", title: "Quick tip", description: "", length: 31},
        %{youtube_id: "medium", title: "Studio lesson", description: "camera setup", length: 90},
        %{youtube_id: "long", title: "Full episode", description: "", length: 600}
      ]

      {:ok, videos: videos}
    end

    test "keeps videos at least the entered duration long", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "", 60)) == ["medium", "long"]
      assert ids(YoutubeImport.filtered_videos(videos, "", 91)) == ["long"]
    end

    test "min of 0 does not hide shorts", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "", 0)) == ["short", "medium", "long"]
    end

    test "combines title filter with min duration", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "studio", 60)) == ["medium"]
    end
  end

  defp ids(videos), do: Enum.map(videos, & &1.youtube_id)
end
