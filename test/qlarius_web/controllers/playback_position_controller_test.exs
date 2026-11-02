defmodule QlariusWeb.PlaybackPositionControllerTest do
  use QlariusWeb.ConnCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.TargetingFixtures
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, Tiqit}
  alias Qlarius.Tiqit.PlaybackPositions

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

    piece =
      %ContentPiece{
        content_group_id: group.id,
        media_type: "audio",
        file_url: "https://cdn.example.com/ep.mp3"
      }
      |> ContentPiece.changeset(%{title: "Episode", date_published: ~D[2025-06-01]})
      |> Repo.insert!()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    tiqit =
      %Tiqit{me_file_id: user.me_file.id}
      |> Tiqit.changeset(%{
        purchased_at: now,
        expires_at: DateTime.add(now, 24, :hour),
        content_piece_id: piece.id
      })
      |> Repo.insert!()

    token = PlaybackPositions.sign_token(user.me_file.id, tiqit.id, piece.id)

    %{token: token, tiqit: tiqit, piece: piece}
  end

  test "a signed beacon saves the position", %{
    conn: conn,
    token: token,
    tiqit: tiqit,
    piece: piece
  } do
    conn =
      post(conn, ~p"/playback_positions", %{
        "token" => token,
        "tiqit_id" => tiqit.id,
        "content_piece_id" => piece.id,
        "position_seconds" => "80",
        "duration_seconds" => "1000",
        "reason" => "hide"
      })

    assert response(conn, 204)
    assert PlaybackPositions.resume(tiqit.id, piece.id) == 80
  end

  test "a bad token is unauthorized", %{conn: conn, tiqit: tiqit, piece: piece} do
    conn =
      post(conn, ~p"/playback_positions", %{
        "token" => "nope",
        "tiqit_id" => tiqit.id,
        "content_piece_id" => piece.id,
        "position_seconds" => "80",
        "duration_seconds" => "1000",
        "reason" => "hide"
      })

    assert json_response(conn, 401)["error"] == "unauthorized"
  end
end
