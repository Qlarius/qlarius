defmodule QlariusWeb.Creators.ContentGroupLive.YoutubeImportTest do
  use ExUnit.Case, async: true

  alias QlariusWeb.Creators.ContentGroupLive.YoutubeImport

  describe "filtered_videos/3" do
    setup do
      videos = [
        %{youtube_id: "short", title: "Quick tip", description: "", length: 31},
        %{youtube_id: "medium", title: "Studio lesson", description: "camera setup", length: 90},
        %{youtube_id: "long", title: "Full episode", description: "", length: 600}
      ]

      {:ok, videos: videos}
    end

    test "keeps videos at least the entered minutes long", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "", 1)) == ["medium", "long"]
      assert ids(YoutubeImport.filtered_videos(videos, "", 2)) == ["long"]
    end

    test "min minutes of 0 does not hide shorts", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "", 0)) == ["short", "medium", "long"]
    end

    test "combines title filter with min minutes", %{videos: videos} do
      assert ids(YoutubeImport.filtered_videos(videos, "studio", 1)) == ["medium"]
    end
  end

  defp ids(videos), do: Enum.map(videos, & &1.youtube_id)
end
