defmodule QlariusWeb.Components.TiqitUnlockedContentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece}
  alias QlariusWeb.Components.TiqitUnlockedContent

  @group %ContentGroup{id: 1, title: "Shane and Sally", catalog: %Catalog{id: 1, creator_id: 1}}
  @tiqit %{expires_at: DateTime.add(DateTime.utc_now(), 3600)}

  test "audio pieces get an audio player instead of the YouTube embed" do
    piece = %ContentPiece{
      id: 1,
      title: "Episode 1",
      media_type: "audio",
      file_url: "https://audio.example.com/e1.mp3"
    }

    html = render_player(piece)

    assert html =~ ~s(<audio)
    assert html =~ ~s(src="https://audio.example.com/e1.mp3")
    assert html =~ ~s(preload="none")
    refute html =~ "YouTubePoster"
  end

  test "shows the episode label next to the group title" do
    piece = %ContentPiece{
      id: 3,
      title: "Lost Horizons",
      media_type: "audio",
      file_url: "https://audio.example.com/e2.mp3",
      episode_number: 2,
      episode_type: "full"
    }

    assert render_player(piece) =~ "Ep 2"
    assert render_player(%{piece | episode_type: "trailer"}) =~ "Trailer"
  end

  test "youtube pieces keep the YouTube poster" do
    piece = %ContentPiece{id: 2, title: "Video", media_type: "youtube", youtube_id: "abc123def45"}

    html = render_player(piece)

    assert html =~ "YouTubePoster"
    assert html =~ ~s(data-youtube-id="abc123def45")
    refute html =~ "<audio"
  end

  defp render_player(piece) do
    render_component(&TiqitUnlockedContent.tiqit_unlocked_content_player/1,
      id_prefix: "test",
      piece: piece,
      group: @group,
      tiqit: @tiqit
    )
  end
end
