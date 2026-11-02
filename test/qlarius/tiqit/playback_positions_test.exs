defmodule Qlarius.Tiqit.PlaybackPositionsTest do
  use Qlarius.DataCase, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.TargetingFixtures
  alias Qlarius.Tiqit.Arcade.{Arcade, Catalog, ContentGroup, ContentPiece, Tiqit}
  alias Qlarius.Tiqit.PlaybackPosition
  alias Qlarius.Tiqit.PlaybackPositions
  alias QlariusWeb.Components.TiqitUnlockedContent

  setup do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "listener-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = Repo.preload(user, :me_file)
    creator = TargetingFixtures.creator_fixture()

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Show #{System.unique_integer([:positive]) |> rem(1000)}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Season"})
      |> Repo.insert!()

    piece = piece!(group, "audio")
    other = piece!(group, "audio")

    tiqit = tiqit!(user.me_file.id, %{content_group_id: group.id})

    %{user: user, group: group, piece: piece, other: other, tiqit: tiqit}
  end

  test "a group tiqit keeps a position per piece and fleets them together", %{
    user: user,
    piece: piece,
    other: other,
    tiqit: tiqit
  } do
    assert :ok = save(user, tiqit, piece, 120, 1000, "pause")
    assert :ok = save(user, tiqit, other, 40, 1000, "pause")

    assert PlaybackPositions.resume(tiqit.id, piece.id) == 120
    assert PlaybackPositions.resume(tiqit.id, other.id) == 40

    assert {:ok, _} = Arcade.fleet_tiqit!(tiqit)
    assert Repo.aggregate(PlaybackPosition, :count) == 0
    assert PlaybackPositions.resume(tiqit.id, piece.id) == nil
  end

  test "ticks inside ten seconds are ignored, pause and the ending are kept", %{
    user: user,
    piece: piece,
    tiqit: tiqit
  } do
    assert :ok = save(user, tiqit, piece, 3, 1000, "tick")
    refute Repo.get_by(PlaybackPosition, tiqit_id: tiqit.id, content_piece_id: piece.id)

    assert :ok = save(user, tiqit, piece, 30, 1000, "tick")
    assert :ok = save(user, tiqit, piece, 36, 1000, "tick")
    assert PlaybackPositions.resume(tiqit.id, piece.id) == 30

    assert :ok = save(user, tiqit, piece, 36, 1000, "pause")
    assert PlaybackPositions.resume(tiqit.id, piece.id) == 36

    assert :ok = save(user, tiqit, piece, 990, 1000, "ended")
    row = Repo.get_by!(PlaybackPosition, tiqit_id: tiqit.id, content_piece_id: piece.id)
    assert row.position_seconds == 0
    assert row.completed_at
    assert PlaybackPositions.resume(tiqit.id, piece.id) == nil

    assert :ok = save(user, tiqit, piece, 0, 1000, "restart")
    row = Repo.get_by!(PlaybackPosition, tiqit_id: tiqit.id, content_piece_id: piece.id)
    assert row.position_seconds == 0
    refute row.completed_at
  end

  test "a fleeted tiqit cannot save", %{user: user, piece: piece, tiqit: tiqit} do
    assert {:ok, _} = Arcade.fleet_tiqit!(tiqit)
    assert {:error, :unauthorized} = save(user, tiqit, piece, 40, 1000, "pause")
  end

  test "the audio player shows the resume point and youtube does not", %{
    user: user,
    group: group,
    piece: piece,
    tiqit: tiqit
  } do
    assert :ok = save(user, tiqit, piece, 754, 2000, "pause")

    html =
      render_component(&TiqitUnlockedContent.tiqit_unlocked_content_player/1, %{
        id_prefix: "piece",
        piece: piece,
        group: group,
        tiqit: tiqit
      })

    assert html =~ "PlaybackResume"
    assert html =~ "Resumed at 12:34"
    assert html =~ "Start over"
    assert html =~ ~s(data-position-seconds="754")

    youtube = %{piece | media_type: "youtube", youtube_id: "abc123def45"}

    youtube_html =
      render_component(&TiqitUnlockedContent.tiqit_unlocked_content_player/1, %{
        id_prefix: "video",
        piece: youtube,
        group: group,
        tiqit: tiqit
      })

    refute youtube_html =~ "PlaybackResume"
    refute youtube_html =~ "Resumed at"
  end

  defp save(user, tiqit, piece, position, duration, reason) do
    PlaybackPositions.save(user.me_file.id, %{
      "tiqit_id" => tiqit.id,
      "content_piece_id" => piece.id,
      "position_seconds" => position,
      "duration_seconds" => duration,
      "reason" => reason
    })
  end

  defp piece!(group, media_type) do
    %ContentPiece{
      content_group_id: group.id,
      media_type: media_type,
      file_url: "https://cdn.example.com/ep.mp3"
    }
    |> ContentPiece.changeset(%{
      title: "Episode #{System.unique_integer([:positive])}",
      date_published: ~D[2025-06-01]
    })
    |> Repo.insert!()
  end

  defp tiqit!(me_file_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Tiqit{me_file_id: me_file_id}
    |> Tiqit.changeset(
      Map.merge(
        %{
          purchased_at: now,
          expires_at: DateTime.add(now, 24, :hour)
        },
        attrs
      )
    )
    |> Repo.insert!()
  end
end
