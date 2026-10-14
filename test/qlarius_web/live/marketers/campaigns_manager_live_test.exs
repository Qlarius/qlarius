defmodule QlariusWeb.Live.Marketers.CampaignsManagerLiveTest do
  use QlariusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Qlarius.Accounts
  alias Qlarius.Repo

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
        alias: "campaign-edit-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
    %{conn: log_in_user(conn, user)}
  end

  test "edits a campaign's name, end date, and payable flag", %{conn: conn} do
    campaign = campaign_fixture()

    conn =
      post(
        conn,
        ~p"/marketer/select/#{campaign.marketer_id}?#{[return_to: "/marketer/campaigns"]}"
      )

    {:ok, view, html} = live(conn, ~p"/marketer/campaigns")
    assert html =~ "Draft name"

    view |> element("#campaign-#{campaign.id} button[phx-click=edit_campaign]") |> render_click()

    html =
      view
      |> form("#edit-campaign-form",
        campaign: %{
          title: "Spring Shoes",
          end_date: "2026-12-01",
          is_payable: "true",
          is_throttled: "false"
        }
      )
      |> render_submit()

    assert html =~ "Spring Shoes"
    assert html =~ "Ends Dec 1, 2026"
    assert html =~ "Payable"
    refute html =~ "Draft name"

    saved = Repo.reload!(campaign)
    assert saved.title == "Spring Shoes"
    assert saved.is_payable
    assert saved.end_date == ~N[2026-12-01 00:00:00]
  end

  defp campaign_fixture do
    marketer = Qlarius.AdCategoryFixtures.marketer_fixture()

    piece =
      Qlarius.AdCategoryFixtures.media_piece_fixture(
        Qlarius.AdCategoryFixtures.row_fixture(),
        marketer
      )

    target =
      %Target{}
      |> Target.changeset(%{title: "Audience", marketer_id: marketer.id})
      |> Repo.insert!()

    %TargetBand{}
    |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
    |> Repo.insert!()

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{title: "Sequence", marketer_id: marketer.id})
      |> Repo.insert!()

    %MediaRun{}
    |> MediaRun.changeset(%{
      marketer_id: marketer.id,
      media_piece_id: piece.id,
      media_sequence_id: sequence.id,
      sequence_start_phase: 1
    })
    |> Repo.insert!()

    %Campaign{}
    |> Campaign.changeset(%{
      title: "Draft name",
      marketer_id: marketer.id,
      target_id: target.id,
      media_sequence_id: sequence.id,
      start_date: ~N[2026-01-01 00:00:00],
      is_payable: false,
      is_throttled: false
    })
    |> Repo.insert!()
  end
end
