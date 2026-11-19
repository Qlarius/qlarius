defmodule Qlarius.Sponster.Ads.VideoTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts.Marketer
  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Repo
  alias Qlarius.Referrals
  alias Qlarius.Referrals.ReferralClick
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPiecePhase, MediaPieceType, Video}
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Recipient
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Wallets
  alias Qlarius.Wallets.{LedgerEntry, LedgerHeader}
  alias Qlarius.Accounts.User

  import Ecto.Query

  describe "create_video_ad_event/4" do
    test "credits publisher $0.02 at 50% split and reduces sponster keep by $0.02" do
      ctx =
        build_video_context!(
          offer_amt: "0.20",
          base_fee: "0.10",
          markup_multiplier: "1.5"
        )

      assert {:ok, ad_event} =
               Video.create_video_ad_event(ctx.offer, ctx.recipient, 50, "127.0.0.1")

      ad_event = Repo.reload!(ad_event)

      assert ad_event.recipient_id == ctx.recipient.id
      assert Decimal.eq?(ad_event.event_recipient_collect_amt, Decimal.new("0.10"))
      assert Decimal.eq?(ad_event.event_sponster_to_recipient_amt, Decimal.new("0.02"))
      assert Decimal.eq?(ad_event.event_me_file_collect_amt, Decimal.new("0.10"))
      assert Decimal.eq?(ad_event.event_sponster_collect_amt, Decimal.new("0.18"))
      assert Decimal.eq?(ad_event.event_marketer_cost_amt, Decimal.new("0.40"))

      reader_header = Repo.get_by!(LedgerHeader, me_file_id: ctx.reader_me_file.id)
      assert Decimal.eq?(reader_header.balance, Decimal.new("0.10"))

      recipient_header = Repo.get_by!(LedgerHeader, recipient_id: ctx.recipient.id)
      assert Decimal.eq?(recipient_header.balance, Decimal.new("0.12"))

      recipient_entries =
        from(e in LedgerEntry,
          where: e.ledger_header_id == ^recipient_header.id and e.ad_event_id == ^ad_event.id,
          order_by: [asc: e.id]
        )
        |> Repo.all()

      assert [%LedgerEntry{} = me_file_share, %LedgerEntry{} = sponster_share] = recipient_entries
      assert Decimal.eq?(me_file_share.amt, Decimal.new("0.10"))
      assert Decimal.eq?(me_file_share.running_balance, Decimal.new("0.10"))
      assert Decimal.eq?(sponster_share.amt, Decimal.new("0.02"))
      assert Decimal.eq?(sponster_share.running_balance, Decimal.new("0.12"))

      campaign_header = Repo.get_by!(LedgerHeader, campaign_id: ctx.campaign.id)
      assert Decimal.eq?(campaign_header.balance, Decimal.new("-0.40"))

      sponster_header = Repo.get!(LedgerHeader, Wallets.sponster_ledger_header_id())
      assert Decimal.eq?(sponster_header.balance, Decimal.new("0.18"))
    end

    test "does not credit a publisher when split is 0%" do
      ctx = build_video_context!(offer_amt: "0.20")

      assert {:ok, ad_event} =
               Video.create_video_ad_event(ctx.offer, ctx.recipient, 0, "127.0.0.1")

      ad_event = Repo.reload!(ad_event)

      assert is_nil(ad_event.recipient_id)
      assert is_nil(ad_event.event_sponster_to_recipient_amt)

      reader_header = Repo.get_by!(LedgerHeader, me_file_id: ctx.reader_me_file.id)
      assert Decimal.eq?(reader_header.balance, Decimal.new("0.20"))

      recipient_header = Repo.get_by!(LedgerHeader, recipient_id: ctx.recipient.id)
      assert Decimal.eq?(recipient_header.balance, Decimal.new("0.00"))
    end

    test "does not credit a publisher when there is no recipient" do
      ctx = build_video_context!(offer_amt: "0.20", with_recipient: false)

      assert {:ok, ad_event} = Video.create_video_ad_event(ctx.offer, nil, 50, "127.0.0.1")
      ad_event = Repo.reload!(ad_event)

      assert is_nil(ad_event.recipient_id)
      assert is_nil(ad_event.event_sponster_to_recipient_amt)

      reader_header = Repo.get_by!(LedgerHeader, me_file_id: ctx.reader_me_file.id)
      assert Decimal.eq?(reader_header.balance, Decimal.new("0.20"))
    end

    test "caps the publisher credit when sponster keep is smaller than $0.02" do
      ctx =
        build_video_context!(
          offer_amt: "0.10",
          base_fee: "0.01",
          markup_multiplier: "1.0"
        )

      assert {:ok, ad_event} =
               Video.create_video_ad_event(ctx.offer, ctx.recipient, 50, "127.0.0.1")

      ad_event = Repo.reload!(ad_event)

      assert Decimal.eq?(ad_event.event_recipient_collect_amt, Decimal.new("0.05"))
      assert Decimal.eq?(ad_event.event_sponster_to_recipient_amt, Decimal.new("0.01"))
      assert Decimal.eq?(ad_event.event_sponster_collect_amt, Decimal.new("0.00"))

      recipient_header = Repo.get_by!(LedgerHeader, recipient_id: ctx.recipient.id)
      assert Decimal.eq?(recipient_header.balance, Decimal.new("0.06"))
    end

    test "creates a referral click when the me_file has an active referral" do
      ctx = build_video_context!(offer_amt: "0.20")
      referrer_me_file = insert_me_file!()

      assert {:ok, referral} =
               Referrals.create_referral("mefile", referrer_me_file.id, ctx.reader_me_file.id)

      assert {:ok, ad_event} =
               Video.create_video_ad_event(ctx.offer, ctx.recipient, 50, "127.0.0.1")

      assert %ReferralClick{} = Repo.get_by!(ReferralClick, ad_event_id: ad_event.id)

      assert Repo.exists?(
               from(rc in ReferralClick,
                 where: rc.ad_event_id == ^ad_event.id and rc.referral_id == ^referral.id
               )
             )
    end
  end

  defp build_video_context!(opts) do
    ensure_sponster_ledger_header!()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    base_fee = Keyword.get(opts, :base_fee, "0.10")
    markup_multiplier = Keyword.get(opts, :markup_multiplier, "1.5")
    offer_amt = Keyword.get(opts, :offer_amt, "0.20")
    with_recipient? = Keyword.get(opts, :with_recipient, true)

    reader_me_file = insert_me_file!()

    marketer =
      %Marketer{}
      |> Marketer.changeset(%{
        business_name: "Video Marketer #{System.unique_integer([:positive])}"
      })
      |> Repo.insert!()

    ensure_video_type_and_phase!(now, base_fee: base_fee, markup_multiplier: markup_multiplier)

    category = AdCategoryFixtures.row_fixture()

    media_piece =
      %MediaPiece{}
      |> MediaPiece.changeset(%{
        title: "Video Ad #{System.unique_integer([:positive])}",
        media_piece_type_id: 2,
        ad_category_id: category.id,
        marketer_id: marketer.id,
        active: true,
        video_file: "video.mp4",
        duration: 30
      })
      |> Repo.insert!()

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{
        title: "Video Seq #{System.unique_integer([:positive])}",
        marketer_id: marketer.id
      })
      |> Repo.insert!()

    media_run =
      %MediaRun{}
      |> MediaRun.changeset(%{
        marketer_id: marketer.id,
        media_piece_id: media_piece.id,
        media_sequence_id: sequence.id,
        frequency: 1,
        frequency_buffer_hours: 24,
        is_active: true,
        sequence_start_phase: 1,
        sequence_end_phase: 1
      })
      |> Repo.insert!()

    target =
      %Target{}
      |> Target.changeset(%{
        title: "Video Target #{System.unique_integer([:positive])}",
        marketer_id: marketer.id
      })
      |> Repo.insert!()

    target_band =
      %TargetBand{}
      |> TargetBand.changeset(%{target_id: target.id, is_bullseye: "1"})
      |> Repo.insert!()

    campaign =
      %Campaign{}
      |> Campaign.changeset(%{
        marketer_id: marketer.id,
        title: "Video Campaign #{System.unique_integer([:positive])}",
        target_id: target.id,
        media_sequence_id: sequence.id,
        start_date: now,
        launched_at: now,
        is_payable: true,
        is_throttled: false
      })
      |> Repo.insert!()

    insert_ledger_header!(%{
      description: "Campaign: #{campaign.title}",
      balance: Decimal.new("0.00"),
      balance_payable: Decimal.new("0.00"),
      campaign_id: campaign.id,
      marketer_id: marketer.id
    })

    recipient =
      if with_recipient? do
        publisher_user = insert_user!()

        %Recipient{}
        |> Recipient.changeset(%{
          user_id: publisher_user.id,
          name: "Publisher #{System.unique_integer([:positive])}",
          site_url: "https://example.com",
          recipient_type_id: 1,
          split_code: Ecto.UUID.generate()
        })
        |> Repo.insert!()
        |> then(fn recipient ->
          insert_ledger_header!(%{
            description: "Ledger for #{recipient.name}",
            balance: Decimal.new("0.00"),
            balance_payable: Decimal.new("0.00"),
            recipient_id: recipient.id
          })

          recipient
        end)
      else
        nil
      end

    insert_ledger_header!(%{
      description: "MeFile #{reader_me_file.id}",
      balance: Decimal.new("0.00"),
      balance_payable: Decimal.new("0.00"),
      me_file_id: reader_me_file.id
    })

    offer =
      %Offer{}
      |> Offer.changeset(%{
        campaign_id: campaign.id,
        me_file_id: reader_me_file.id,
        media_run_id: media_run.id,
        media_piece_id: media_piece.id,
        target_band_id: target_band.id,
        offer_amt: Decimal.new(offer_amt),
        marketer_cost_amt: Decimal.new("0.00"),
        pending_until: now,
        is_payable: true,
        is_throttled: false,
        is_jobbed: false,
        matching_tags_snapshot: %{},
        ad_phase_count_to_complete: 1,
        is_current: true
      })
      |> Repo.insert!()

    %{
      reader_me_file: reader_me_file,
      marketer: marketer,
      campaign: campaign,
      recipient: recipient,
      offer: offer
    }
  end

  defp ensure_video_type_and_phase!(now, opts) do
    base_fee = Keyword.fetch!(opts, :base_fee) |> Decimal.new()
    markup_multiplier = Keyword.fetch!(opts, :markup_multiplier) |> Decimal.new()

    Repo.insert!(
      %MediaPieceType{
        id: 2,
        name: "video",
        desc: "Video",
        ad_phase_count_to_complete: 1,
        base_fee: base_fee,
        markup_multiplier: markup_multiplier,
        created_at: now
      },
      on_conflict: [
        set: [
          base_fee: base_fee,
          markup_multiplier: markup_multiplier
        ]
      ],
      conflict_target: :id
    )

    case Repo.get_by(MediaPiecePhase, media_piece_type_id: 2, phase: 1) do
      nil ->
        %MediaPiecePhase{}
        |> MediaPiecePhase.changeset(%{
          media_piece_type_id: 2,
          phase: 1,
          name: "Video",
          desc: "Video",
          is_final_phase: true
        })
        |> Repo.insert!()

      %MediaPiecePhase{} = phase ->
        phase
        |> Ecto.Changeset.change(is_final_phase: true)
        |> Repo.update!()
    end

    :ok
  end

  defp ensure_sponster_ledger_header! do
    id = Wallets.sponster_ledger_header_id()

    unless Repo.get(LedgerHeader, id) do
      Repo.insert!(%LedgerHeader{
        id: id,
        description: "SPONSTER",
        balance: Decimal.new("0.00"),
        balance_payable: Decimal.new("0.00")
      })
    end

    :ok
  end

  defp insert_user! do
    %User{}
    |> User.registration_changeset(%{
      alias: "video-#{System.unique_integer([:positive])}",
      role: "consumer"
    })
    |> Repo.insert!()
  end

  defp insert_me_file! do
    user = insert_user!()

    %MeFile{}
    |> MeFile.changeset(%{
      user_id: user.id,
      date_of_birth: ~D[1990-01-01]
    })
    |> Repo.insert!()
  end

  defp insert_ledger_header!(attrs) do
    attrs = Map.new(attrs)

    id = 1_000_000_000 + System.unique_integer([:positive])

    Repo.insert!(struct(LedgerHeader, Map.put(attrs, :id, id)))
  end
end
