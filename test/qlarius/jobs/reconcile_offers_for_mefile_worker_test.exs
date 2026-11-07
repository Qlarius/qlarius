defmodule Qlarius.Jobs.ReconcileOffersForMeFileWorkerTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Jobs.ReconcileOffersForMeFileWorker
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategory, MediaPiece, MediaPieceType}

  alias Qlarius.Sponster.Campaigns.{
    Bid,
    Campaign,
    MediaRun,
    MediaSequence,
    Target,
    TargetBand,
    TargetPopulation
  }

  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Offers
  alias Qlarius.YouData.MeFiles.MeFile

  test "does not create offers for draft (unlaunched) campaigns, but does for launched campaigns" do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    me_file = Repo.insert!(%MeFile{})
    marketer = Repo.insert!(Marketer.changeset(%Marketer{}, %{business_name: "M #{uniq()}"}))

    ensure_three_tap_type!(now)
    category = insert_category!()
    piece = insert_three_tap_piece!(marketer.id, category.id)
    sequence = insert_sequence!(marketer.id)
    run = insert_run!(marketer.id, sequence.id, piece.id)
    target = insert_target!(marketer.id)
    band = insert_band!(target.id)

    draft_campaign =
      insert_campaign!(%{
        marketer_id: marketer.id,
        target_id: target.id,
        media_sequence_id: sequence.id,
        title: "Draft #{uniq()}",
        start_date: now,
        launched_at: nil,
        is_payable: true,
        is_throttled: false
      })

    Repo.insert!(
      Bid.changeset(%Bid{}, %{
        campaign_id: draft_campaign.id,
        media_run_id: run.id,
        target_band_id: band.id,
        offer_amt: Decimal.new("0.21"),
        marketer_cost_amt: Decimal.new("0.30")
      })
    )

    Repo.insert!(
      TargetPopulation.changeset(%TargetPopulation{}, %{
        me_file_id: me_file.id,
        target_band_id: band.id,
        matching_tags_snapshot: %{tags: []}
      })
    )

    assert :ok =
             ReconcileOffersForMeFileWorker.perform(%Oban.Job{
               args: %{"me_file_id" => me_file.id}
             })

    refute Repo.exists?(
             from(o in Offer,
               where: o.campaign_id == ^draft_campaign.id and o.me_file_id == ^me_file.id
             )
           )

    launched_campaign =
      draft_campaign
      |> Ecto.Changeset.change(%{launched_at: now})
      |> Repo.update!()

    assert :ok =
             ReconcileOffersForMeFileWorker.perform(%Oban.Job{
               args: %{"me_file_id" => me_file.id}
             })

    assert Repo.exists?(
             from(o in Offer,
               where: o.campaign_id == ^launched_campaign.id and o.me_file_id == ^me_file.id
             )
           )
  end

  describe "throttled offers" do
    test "creates every eligible offer and marks only throttle_ad_count current" do
      me_file = setup_throttled_bids!(4, throttle_ad_count: 2)

      assert :ok =
               ReconcileOffersForMeFileWorker.perform(%Oban.Job{
                 args: %{"me_file_id" => me_file.id}
               })

      assert %{total: 4, current: 2} = counts(me_file)
    end

    test "reset_for_me_file rebuilds every offer with the throttle applied" do
      me_file = setup_throttled_bids!(4, throttle_ad_count: 3)

      ReconcileOffersForMeFileWorker.perform(%Oban.Job{args: %{"me_file_id" => me_file.id}})

      Repo.update_all(from(o in Offer, where: o.me_file_id == ^me_file.id),
        set: [is_current: false]
      )

      assert {:ok, %{deleted: 4, created: 4, current: 3}} = Offers.reset_for_me_file(me_file.id)
      assert %{total: 4, current: 3} = counts(me_file)
    end
  end

  defp setup_throttled_bids!(bid_count, throttle_ad_count: limit) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    me_file = Repo.insert!(%MeFile{throttle_ad_count: limit, throttle_days: 7})
    marketer = Repo.insert!(Marketer.changeset(%Marketer{}, %{business_name: "M #{uniq()}"}))

    ensure_three_tap_type!(now)
    category = insert_category!()
    sequence = insert_sequence!(marketer.id)
    target = insert_target!(marketer.id)
    band = insert_band!(target.id)

    campaign =
      insert_campaign!(%{
        marketer_id: marketer.id,
        target_id: target.id,
        media_sequence_id: sequence.id,
        title: "Throttled #{uniq()}",
        start_date: now,
        launched_at: now,
        is_payable: true,
        is_throttled: true
      })

    for _ <- 1..bid_count do
      piece = insert_three_tap_piece!(marketer.id, category.id)
      run = insert_run!(marketer.id, sequence.id, piece.id)

      Repo.insert!(
        Bid.changeset(%Bid{}, %{
          campaign_id: campaign.id,
          media_run_id: run.id,
          target_band_id: band.id,
          offer_amt: Decimal.new("0.21"),
          marketer_cost_amt: Decimal.new("0.30")
        })
      )
    end

    Repo.insert!(
      TargetPopulation.changeset(%TargetPopulation{}, %{
        me_file_id: me_file.id,
        target_band_id: band.id,
        matching_tags_snapshot: %{tags: []}
      })
    )

    me_file
  end

  defp counts(me_file) do
    Map.fetch!(Offers.offer_counts([me_file.id]), me_file.id)
  end

  defp insert_campaign!(attrs) do
    %Campaign{}
    |> Campaign.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_sequence!(marketer_id) do
    %MediaSequence{}
    |> MediaSequence.changeset(%{title: "Seq #{uniq()}", marketer_id: marketer_id})
    |> Repo.insert!()
  end

  defp insert_run!(marketer_id, sequence_id, piece_id) do
    %MediaRun{}
    |> MediaRun.changeset(%{
      marketer_id: marketer_id,
      media_sequence_id: sequence_id,
      media_piece_id: piece_id,
      is_active: true,
      sequence_start_phase: 1,
      sequence_end_phase: 2,
      frequency: 1,
      frequency_buffer_hours: 0
    })
    |> Repo.insert!()
  end

  defp insert_target!(marketer_id) do
    %Target{}
    |> Target.changeset(%{title: "Target #{uniq()}", marketer_id: marketer_id})
    |> Repo.insert!()
  end

  defp insert_band!(target_id) do
    %TargetBand{}
    |> TargetBand.changeset(%{target_id: target_id, is_bullseye: "1"})
    |> Repo.insert!()
  end

  defp ensure_three_tap_type!(now) do
    unless Repo.get(MediaPieceType, 1) do
      Repo.insert!(%MediaPieceType{
        id: 1,
        name: "three_tap",
        desc: "3-tap",
        ad_phase_count_to_complete: 2,
        base_fee: Decimal.new("0.10"),
        markup_multiplier: Decimal.new("1.5"),
        created_at: now
      })
    end
  end

  defp insert_category! do
    n = System.unique_integer([:positive])
    row_id = "TEST-" <> (n |> Integer.to_string() |> String.pad_leading(2, "0"))

    %AdCategory{}
    |> AdCategory.create_changeset(%{
      row_id: row_id,
      category_id: "TEST",
      category_name: "Test",
      category_label: "Test",
      ad_label: "Cat #{n}",
      sales_channel_default: "local",
      sort_order: n,
      cohort: "legacy",
      active: true
    })
    |> Repo.insert!()
  end

  defp insert_three_tap_piece!(marketer_id, category_id) do
    %MediaPiece{}
    |> MediaPiece.changeset(%{
      title: "Ad #{uniq()}",
      body_copy: "Body #{uniq()}",
      media_piece_type_id: 1,
      ad_category_id: category_id,
      marketer_id: marketer_id,
      active: true,
      banner_image: "banner.png",
      display_url: "example.com",
      jump_url: "https://example.com/jump"
    })
    |> Repo.insert!()
  end

  defp uniq, do: System.unique_integer([:positive])
end
