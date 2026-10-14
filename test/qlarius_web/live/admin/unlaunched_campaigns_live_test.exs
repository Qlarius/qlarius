defmodule QlariusWeb.Admin.UnlaunchedCampaignsLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Qlarius.AdCategoryFixtures

  import Qlarius.TargetingFixtures,
    only: [
      parent_trait_fixture: 1,
      trait_fixture: 2,
      trait_group_fixture: 2,
      target_fixture: 2
    ]

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPieceType}
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence}

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "unlaunched-admin-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user)}
  end

  test "lists unlaunched campaigns with a preview and a review link", %{conn: conn} do
    marketer = marketer_fixture()
    piece = media_piece_fixture(row_fixture(), marketer)
    draft = campaign_with_piece!(marketer, piece, "Spring Shoes")

    launched = campaign_with_piece!(marketer, piece, "Already Live")

    launched
    |> Ecto.Changeset.change(%{
      launched_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update!()

    deactivated = campaign_with_piece!(marketer, piece, "Put Away")

    deactivated
    |> Ecto.Changeset.change(%{
      deactivated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update!()

    {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

    assert html =~ "Spring Shoes"
    assert html =~ marketer.business_name
    assert html =~ "banner.png"
    refute html =~ "Already Live"
    refute html =~ "Put Away"

    assert html =~
             ~s(href="/marketer/select/#{marketer.id}?return_to=%2Fmarketer%2Fcampaigns%3Fcampaign%3D#{draft.id}")
  end

  test "reviewing lands on that campaign for its marketer", %{conn: conn} do
    marketer = marketer_fixture()
    piece = media_piece_fixture(row_fixture(), marketer)
    parent = parent_trait_fixture("Interests")
    group = trait_group_fixture(%{marketer_id: marketer.id}, [trait_fixture(parent, "Music")])
    target = target_fixture(%{marketer_id: marketer.id}, [[group]])
    draft = campaign_with_piece!(marketer, piece, "Spring Shoes", target)
    _other = campaign_with_piece!(marketer, piece, "Other Draft", target)

    conn =
      post(conn, ~p"/marketer/select/#{marketer.id}?#{[return_to: "/marketer/campaigns"]}")

    {:ok, _view, html} = live(conn, ~p"/marketer/campaigns?campaign=#{draft.id}")

    assert html =~ "Spring Shoes"
    assert html =~ "Other Draft"
    assert Regex.scan(~r/phx-hook="ScrollIntoView"/, html) |> length() == 1
    assert Regex.scan(~r/ring-2 ring-primary/, html) |> length() == 1
    assert html =~ ~s(id="campaign-#{draft.id}")
  end

  test "a video campaign previews its poster", %{conn: conn} do
    marketer = marketer_fixture()
    ensure_video_type!()

    piece =
      %MediaPiece{}
      |> MediaPiece.changeset(%{
        title: "Spot",
        media_piece_type_id: 2,
        ad_category_id: row_fixture().id,
        marketer_id: marketer.id,
        active: true,
        duration: 15,
        video_file: "spot.mp4",
        video_poster_image: "poster.jpg",
        display_url: "example.com",
        jump_url: "https://example.com/jump"
      })
      |> Repo.insert!()

    campaign_with_piece!(marketer, piece, "Video Draft")

    {:ok, _view, html} = live(conn, ~p"/admin/campaigns")

    assert html =~ "Video Draft"
    assert html =~ "poster.jpg"
    refute html =~ "banner.png"
  end

  defp ensure_video_type! do
    unless Repo.get(MediaPieceType, 2) do
      Repo.insert!(%MediaPieceType{
        id: 2,
        name: "video",
        desc: "Video",
        ad_phase_count_to_complete: 1,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
    end
  end

  defp campaign_with_piece!(marketer, piece, title, target \\ nil) do
    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{title: "#{title} sequence", marketer_id: marketer.id})
      |> Repo.insert!()

    %MediaRun{}
    |> MediaRun.changeset(%{
      media_piece_id: piece.id,
      media_sequence_id: sequence.id,
      marketer_id: marketer.id,
      sequence_start_phase: 1
    })
    |> Repo.insert!()

    attrs = %{
      title: title,
      marketer_id: marketer.id,
      media_sequence_id: sequence.id,
      start_date: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }

    attrs = if target, do: Map.put(attrs, :target_id, target.id), else: attrs

    %Campaign{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end
end
