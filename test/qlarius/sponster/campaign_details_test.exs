defmodule Qlarius.Sponster.CampaignDetailsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns
  alias Qlarius.Sponster.Offer

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    MediaRun,
    MediaSequence,
    Target,
    TargetBand
  }

  test "updates the name, end date, and flags, including current offers" do
    campaign = campaign_fixture()
    offer = offer_fixture(campaign)

    ends = NaiveDateTime.new!(~D[2026-12-01], ~T[00:00:00])

    assert {:ok, updated} =
             Campaigns.update_campaign_details(campaign, %{
               "title" => "Spring Shoes",
               "end_date" => "2026-12-01",
               "is_payable" => "true",
               "is_throttled" => "true",
               "target_id" => 0
             })

    assert updated.title == "Spring Shoes"
    assert updated.end_date == ends
    assert updated.is_payable
    assert updated.is_throttled
    assert updated.target_id == campaign.target_id

    offer = Repo.reload!(offer)
    assert offer.is_payable
    assert offer.is_throttled
  end

  test "a blank name is rejected and offers stay as they were" do
    campaign = campaign_fixture()
    offer = offer_fixture(campaign)

    assert {:error, changeset} =
             Campaigns.update_campaign_details(campaign, %{"title" => "", "is_payable" => "true"})

    assert %{title: ["can't be blank"]} = errors_on(changeset)
    refute Repo.reload!(offer).is_payable
  end

  test "clearing the end date removes it" do
    campaign = campaign_fixture()

    {:ok, campaign} =
      Campaigns.update_campaign_details(campaign, %{"end_date" => "2026-12-01"})

    assert {:ok, updated} = Campaigns.update_campaign_details(campaign, %{"end_date" => ""})
    assert updated.end_date == nil
  end

  defp campaign_fixture do
    marketer = Qlarius.AdCategoryFixtures.marketer_fixture()

    target =
      %Target{}
      |> Target.changeset(%{title: "Target", marketer_id: marketer.id})
      |> Repo.insert!()

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{title: "Sequence", marketer_id: marketer.id})
      |> Repo.insert!()

    %Campaign{}
    |> Campaign.changeset(%{
      title: "Draft",
      marketer_id: marketer.id,
      target_id: target.id,
      media_sequence_id: sequence.id,
      start_date: ~N[2026-01-01 00:00:00],
      is_payable: false,
      is_throttled: false
    })
    |> Repo.insert!()
  end

  defp offer_fixture(campaign) do
    piece =
      Qlarius.AdCategoryFixtures.media_piece_fixture(Qlarius.AdCategoryFixtures.row_fixture())

    %TargetBand{}
    |> TargetBand.changeset(%{target_id: campaign.target_id, is_bullseye: "1"})
    |> Repo.insert!()
    |> then(fn band ->
      run =
        %MediaRun{}
        |> MediaRun.changeset(%{
          marketer_id: campaign.marketer_id,
          media_piece_id: piece.id,
          media_sequence_id: campaign.media_sequence_id
        })
        |> Repo.insert!()

      me_file = Qlarius.TargetingFixtures.me_file_fixture()

      %Offer{}
      |> Offer.changeset(%{
        campaign_id: campaign.id,
        me_file_id: me_file.id,
        media_run_id: run.id,
        media_piece_id: piece.id,
        target_band_id: band.id,
        offer_amt: Decimal.new("1.00"),
        marketer_cost_amt: Decimal.new("1.00"),
        ad_phase_count_to_complete: 2,
        matching_tags_snapshot: %{},
        is_payable: false,
        is_throttled: false
      })
      |> Repo.insert!()
    end)
  end
end
