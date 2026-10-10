defmodule QlariusWeb.AdJumpPageControllerTest do
  use QlariusWeb.ConnCase

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    MediaRun,
    MediaSequence,
    Target,
    TargetBand
  }

  setup %{conn: conn} do
    {:ok, %{user: user}} =
      Accounts.register_new_user(%{
        alias: "test-user-#{System.unique_integer([:positive])}"
      })

    %{conn: log_in_user(conn, user), user: user}
  end

  describe "GET /jump/:id (exit hatch)" do
    test "renders a Back to app link using return_to when provided", %{conn: conn} do
      offer = offer_fixture()
      conn = %{conn | host: "qadabra.app"}

      return_to = "/ads?tab=three_tap"
      conn = get(conn, ~p"/jump/#{offer.id}?#{%{return_to: return_to}}")
      html = html_response(conn, 200)

      assert html =~ ~s(id="ad-jump-exit")
      assert html =~ ~s(href="#{return_to}")
      assert html =~ ~s(data-exit-to-app)
      assert html =~ "window.opener"
    end

    test "falls back to /ads on qadabra hosts when origin is missing", %{conn: conn} do
      offer = offer_fixture()
      conn = %{conn | host: "qadabra.app"}

      conn = get(conn, ~p"/jump/#{offer.id}")
      html = html_response(conn, 200)

      assert html =~ ~s(id="ad-jump-exit")
      assert html =~ ~s(href="/ads")
    end
  end

  defp offer_fixture do
    category = Qlarius.AdCategoryFixtures.row_fixture()
    media_piece = Qlarius.AdCategoryFixtures.media_piece_fixture(category)
    marketer_id = media_piece.marketer_id

    target =
      %Target{}
      |> Target.changeset(%{
        title: "Target #{System.unique_integer([:positive])}",
        marketer_id: marketer_id
      })
      |> Repo.insert!()

    target_band =
      %TargetBand{}
      |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
      |> Repo.insert!()

    media_sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{
        title: "Media sequence #{System.unique_integer([:positive])}",
        marketer_id: marketer_id
      })
      |> Repo.insert!()

    campaign =
      %Campaign{}
      |> Campaign.changeset(%{
        title: "Campaign #{System.unique_integer([:positive])}",
        marketer_id: marketer_id,
        target_id: target.id,
        media_sequence_id: media_sequence.id,
        start_date: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
      |> Repo.insert!()

    media_run =
      %MediaRun{}
      |> MediaRun.changeset(%{
        marketer_id: marketer_id,
        media_piece_id: media_piece.id,
        media_sequence_id: media_sequence.id
      })
      |> Repo.insert!()

    me_file = Qlarius.TargetingFixtures.me_file_fixture()

    %Offer{}
    |> Offer.changeset(%{
      campaign_id: campaign.id,
      me_file_id: me_file.id,
      media_run_id: media_run.id,
      media_piece_id: media_piece.id,
      target_band_id: target_band.id,
      offer_amt: Decimal.new("1.00"),
      marketer_cost_amt: Decimal.new("1.00"),
      ad_phase_count_to_complete: 2,
      matching_tags_snapshot: %{}
    })
    |> Repo.insert!()
  end
end
