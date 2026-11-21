defmodule Qlarius.Sponster.Ads.ThreeTapTest do
  use Qlarius.DataCase, async: false

  alias Qlarius.Accounts.{Marketer, User}
  alias Qlarius.AdCategoryFixtures
  alias Qlarius.Repo
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPiecePhase, MediaPieceType, ThreeTap}
  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, MediaSequence, Target, TargetBand}
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Wallets
  alias Qlarius.Wallets.{LedgerEntry, LedgerHeader}
  alias Qlarius.YouData.MeFiles.MeFile

  import Ecto.Query

  test "a banner still pays the publisher $0.01 when the reader keeps the whole collect" do
    for split <- [0, nil] do
      ctx = build_three_tap_context!()

      assert {:ok, ad_event} =
               ThreeTap.create_banner_ad_event(ctx.offer, ctx.recipient, split, "127.0.0.1")

      ad_event = Repo.reload!(ad_event)

      assert ad_event.recipient_id == ctx.recipient.id
      assert is_nil(ad_event.event_recipient_collect_amt)
      assert Decimal.eq?(ad_event.event_sponster_to_recipient_amt, Decimal.new("0.01"))
      assert Decimal.eq?(ad_event.event_me_file_collect_amt, Decimal.new("0.05"))
      assert Decimal.eq?(ad_event.event_sponster_collect_amt, Decimal.new("0.00"))
      assert Decimal.eq?(ad_event.event_marketer_cost_amt, Decimal.new("0.06"))

      reader_header = Repo.get_by!(LedgerHeader, me_file_id: ctx.reader_me_file.id)
      assert Decimal.eq?(reader_header.balance, Decimal.new("0.05"))

      recipient_header = Repo.get_by!(LedgerHeader, recipient_id: ctx.recipient.id)
      assert Decimal.eq?(recipient_header.balance, Decimal.new("0.01"))

      entries = recipient_entries(recipient_header, ad_event)
      assert [%LedgerEntry{description: description, amt: amt}] = entries
      assert description =~ "SPONSTER"
      assert Decimal.eq?(amt, Decimal.new("0.01"))
    end
  end

  test "a banner with no recipient pays the reader and no publisher" do
    ctx = build_three_tap_context!(with_recipient: false)

    assert {:ok, ad_event} = ThreeTap.create_banner_ad_event(ctx.offer, nil, 50, "127.0.0.1")
    ad_event = Repo.reload!(ad_event)

    assert is_nil(ad_event.recipient_id)
    assert is_nil(ad_event.event_sponster_to_recipient_amt)
    assert Decimal.eq?(ad_event.event_me_file_collect_amt, Decimal.new("0.05"))
    assert Decimal.eq?(ad_event.event_sponster_collect_amt, Decimal.new("0.01"))
  end

  test "a jump with autosplit off still credits the publisher and keeps the reader's collect" do
    ctx = build_three_tap_context!()

    assert {:ok, ad_event} =
             ThreeTap.create_jump_ad_event(ctx.offer, ctx.recipient, 0, "127.0.0.1")

    ad_event = Repo.reload!(ad_event)

    assert ad_event.recipient_id == ctx.recipient.id
    assert is_nil(ad_event.event_recipient_collect_amt)
    assert Decimal.eq?(ad_event.event_sponster_to_recipient_amt, Decimal.new("0.01"))
    assert Decimal.eq?(ad_event.event_me_file_collect_amt, Decimal.new("0.15"))
    assert Decimal.eq?(ad_event.event_sponster_collect_amt, Decimal.new("0.08"))
    assert Decimal.eq?(ad_event.event_marketer_cost_amt, Decimal.new("0.24"))

    reader_header = Repo.get_by!(LedgerHeader, me_file_id: ctx.reader_me_file.id)
    assert Decimal.eq?(reader_header.balance, Decimal.new("0.15"))

    recipient_header = Repo.get_by!(LedgerHeader, recipient_id: ctx.recipient.id)
    assert Decimal.eq?(recipient_header.balance, Decimal.new("0.01"))
    assert [%LedgerEntry{}] = recipient_entries(recipient_header, ad_event)
  end

  test "a 50% split still moves the reader's share and pays the publisher credit on both phases" do
    ctx = build_three_tap_context!()

    assert {:ok, banner} =
             ThreeTap.create_banner_ad_event(ctx.offer, ctx.recipient, 50, "127.0.0.1")

    banner = Repo.reload!(banner)
    assert Decimal.eq?(banner.event_recipient_collect_amt, Decimal.new("0.03"))
    assert Decimal.eq?(banner.event_me_file_collect_amt, Decimal.new("0.02"))
    assert Decimal.eq?(banner.event_sponster_to_recipient_amt, Decimal.new("0.01"))

    assert {:ok, jump} =
             ThreeTap.create_jump_ad_event(ctx.offer, ctx.recipient, 50, "127.0.0.1")

    jump = Repo.reload!(jump)
    assert Decimal.eq?(jump.event_recipient_collect_amt, Decimal.new("0.07"))
    assert Decimal.eq?(jump.event_me_file_collect_amt, Decimal.new("0.08"))
    assert Decimal.eq?(jump.event_sponster_to_recipient_amt, Decimal.new("0.01"))
    assert Decimal.eq?(jump.event_marketer_cost_amt, Decimal.new("0.24"))
  end

  defp recipient_entries(header, ad_event) do
    Repo.all(
      from e in LedgerEntry,
        where: e.ledger_header_id == ^header.id and e.ad_event_id == ^ad_event.id,
        order_by: [asc: e.id]
    )
  end

  defp build_three_tap_context!(opts \\ []) do
    ensure_sponster_ledger_header!()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    with_recipient? = Keyword.get(opts, :with_recipient, true)
    ensure_three_tap_phases!(now)

    reader_me_file = insert_me_file!()

    marketer =
      %Marketer{}
      |> Marketer.changeset(%{
        business_name: "Three Tap #{System.unique_integer([:positive])}"
      })
      |> Repo.insert!()

    category = AdCategoryFixtures.row_fixture()

    media_piece =
      %MediaPiece{}
      |> MediaPiece.changeset(%{
        title: "Banner #{System.unique_integer([:positive])}",
        media_piece_type_id: 1,
        ad_category_id: category.id,
        marketer_id: marketer.id,
        active: true,
        banner_image: "banner.png",
        display_url: "https://advertiser.example",
        jump_url: "https://advertiser.example"
      })
      |> Repo.insert!()

    sequence =
      %MediaSequence{}
      |> MediaSequence.changeset(%{
        title: "Seq #{System.unique_integer([:positive])}",
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
        sequence_end_phase: 2
      })
      |> Repo.insert!()

    target =
      %Target{}
      |> Target.changeset(%{
        title: "Target #{System.unique_integer([:positive])}",
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
        title: "Campaign #{System.unique_integer([:positive])}",
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

        recipient =
          %Recipient{}
          |> Recipient.changeset(%{
            user_id: publisher_user.id,
            name: "Publisher #{System.unique_integer([:positive])}",
            site_url: "https://example.com",
            recipient_type_id: 1,
            split_code: Ecto.UUID.generate()
          })
          |> Repo.insert!()

        insert_ledger_header!(%{
          description: "Ledger for #{recipient.name}",
          balance: Decimal.new("0.00"),
          balance_payable: Decimal.new("0.00"),
          recipient_id: recipient.id
        })

        recipient
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
        offer_amt: Decimal.new("0.20"),
        marketer_cost_amt: Decimal.new("0.30"),
        pending_until: now,
        is_payable: true,
        is_throttled: false,
        is_jobbed: false,
        matching_tags_snapshot: %{},
        ad_phase_count_to_complete: 2,
        is_current: true
      })
      |> Repo.insert!()

    %{reader_me_file: reader_me_file, recipient: recipient, offer: offer}
  end

  defp ensure_three_tap_phases!(now) do
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

    unless Repo.get(MediaPiecePhase, 1) do
      Repo.insert!(%MediaPiecePhase{
        id: 1,
        media_piece_type_id: 1,
        phase: 1,
        name: "Banner",
        desc: "Banner",
        is_final_phase: false,
        pay_to_me_file_fixed: Decimal.new("0.05"),
        pay_to_sponster_fixed: Decimal.new("0.01"),
        created_at: now
      })
    end

    unless Repo.get(MediaPiecePhase, 2) do
      Repo.insert!(%MediaPiecePhase{
        id: 2,
        media_piece_type_id: 1,
        phase: 2,
        name: "Jump",
        desc: "Jump",
        is_final_phase: true,
        pay_to_me_file_fixed: Decimal.new("0.00"),
        pay_to_sponster_fixed: Decimal.new("0.00"),
        created_at: now
      })
    end
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
  end

  defp insert_user! do
    %User{}
    |> User.registration_changeset(%{
      alias: "tap-#{System.unique_integer([:positive])}",
      role: "consumer"
    })
    |> Repo.insert!()
  end

  defp insert_me_file! do
    user = insert_user!()

    %MeFile{}
    |> MeFile.changeset(%{user_id: user.id, date_of_birth: ~D[1990-01-01]})
    |> Repo.insert!()
  end

  defp insert_ledger_header!(attrs) do
    id = 1_000_000_000 + System.unique_integer([:positive])
    Repo.insert!(struct(LedgerHeader, Map.put(Map.new(attrs), :id, id)))
  end
end
