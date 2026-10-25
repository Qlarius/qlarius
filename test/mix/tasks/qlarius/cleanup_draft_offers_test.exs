defmodule Mix.Tasks.Qlarius.CleanupDraftOffersTest do
  use Qlarius.DataCase, async: false

  import ExUnit.CaptureIO

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{AdCategory, MediaPiece, MediaPieceType}
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
  alias Qlarius.Sponster.Offer
  alias Qlarius.YouData.MeFiles.MeFile

  test "dry run prints counts and confirm deletes offers for draft campaigns only" do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %{draft_campaign: draft_campaign, draft_offer: draft_offer, launched_offer: launched_offer} =
      seed_offers!(now)

    dry_run =
      capture_io(fn ->
        Mix.Task.rerun("qlarius.cleanup_draft_offers", [])
      end)

    assert dry_run =~ "Dry run only"
    assert dry_run =~ "campaign_id=#{draft_campaign.id}"

    assert Repo.get(Offer, draft_offer.id)
    assert Repo.get(Offer, launched_offer.id)

    confirm =
      capture_io(fn ->
        Mix.Task.rerun("qlarius.cleanup_draft_offers", ["--confirm"])
      end)

    assert confirm =~ "Deleted offers: 1"
    assert is_nil(Repo.get(Offer, draft_offer.id))
    assert Repo.get(Offer, launched_offer.id)
  end

  defp seed_offers!(now) do
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

    launched_campaign =
      insert_campaign!(%{
        marketer_id: marketer.id,
        target_id: target.id,
        media_sequence_id: sequence.id,
        title: "Launched #{uniq()}",
        start_date: now,
        launched_at: now,
        is_payable: true,
        is_throttled: false
      })

    draft_offer =
      insert_offer!(%{
        campaign_id: draft_campaign.id,
        me_file_id: me_file.id,
        media_run_id: run.id,
        media_piece_id: piece.id,
        target_band_id: band.id,
        offer_amt: Decimal.new("0.21"),
        marketer_cost_amt: Decimal.new("0.30"),
        ad_phase_count_to_complete: 2,
        matching_tags_snapshot: %{},
        pending_until: now,
        is_current: true
      })

    launched_offer =
      insert_offer!(%{
        campaign_id: launched_campaign.id,
        me_file_id: me_file.id,
        media_run_id: run.id,
        media_piece_id: piece.id,
        target_band_id: band.id,
        offer_amt: Decimal.new("0.21"),
        marketer_cost_amt: Decimal.new("0.30"),
        ad_phase_count_to_complete: 2,
        matching_tags_snapshot: %{},
        pending_until: now,
        is_current: true
      })

    %{
      draft_campaign: draft_campaign,
      draft_offer: draft_offer,
      launched_offer: launched_offer
    }
  end

  defp insert_campaign!(attrs) do
    %Campaign{}
    |> Campaign.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_offer!(attrs) do
    %Offer{}
    |> Offer.changeset(attrs)
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
