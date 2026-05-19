defmodule Qlarius.Sponster.LedgerReportingTest do
  use ExUnit.Case, async: true

  alias Qlarius.Sponster.LedgerReporting

  describe "period_to_range/1" do
    test "all returns nil bounds" do
      assert LedgerReporting.period_to_range("all") == {nil, nil}
    end

    test "7d returns a bounded window" do
      {start_at, end_at} = LedgerReporting.period_to_range("7d")
      assert %NaiveDateTime{} = start_at
      assert %NaiveDateTime{} = end_at
      assert NaiveDateTime.compare(start_at, end_at) == :lt
    end

    test "unknown period falls back to default" do
      {start_at, end_at} = LedgerReporting.period_to_range("invalid")
      {default_start, default_end} = LedgerReporting.period_to_range(LedgerReporting.default_period())
      assert start_at == default_start
      assert end_at == default_end
    end
  end
end

defmodule Qlarius.Sponster.LedgerReportingDataTest do
  @moduledoc false
  use Qlarius.DataCase, async: false

  alias Qlarius.Sponster.LedgerReporting
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPieceType}
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Accounts.Marketer
  alias Qlarius.AccountsFixtures
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  describe "summary_stats/2" do
    test "empty database returns zeroed metrics" do
      stats = LedgerReporting.summary_stats(nil, nil)

      assert stats.ad_events == 0
      assert stats.payable_events == 0
      assert Decimal.equal?(stats.sponster_revenue, Decimal.new(0))
    end

    test "aggregates payable ad events" do
      {start_at, end_at} = LedgerReporting.period_to_range("30d")
      insert_payable_ad_event!(Decimal.new("0.10"))

      stats = LedgerReporting.summary_stats(start_at, end_at)

      assert stats.ad_events == 1
      assert stats.payable_events == 1
      assert Decimal.equal?(stats.sponster_revenue, Decimal.new("0.10"))
    end
  end

  describe "revenue_by_ad_unit_type/2" do
    test "groups revenue by media piece type name" do
      {start_at, end_at} = LedgerReporting.period_to_range("30d")
      insert_payable_ad_event!(Decimal.new("0.25"), media_piece_type_name: "video_ad")

      [row] = LedgerReporting.revenue_by_ad_unit_type(start_at, end_at)

      assert row.ad_unit_type == "video_ad"
      assert row.events == 1
      assert Decimal.equal?(row.revenue, Decimal.new("0.25"))
    end
  end

  defp insert_payable_ad_event!(sponster_amt, opts \\ []) do
    type_name = Keyword.get(opts, :media_piece_type_name, "three_tap")

    mpt =
      case Repo.get_by(MediaPieceType, name: type_name) do
        nil ->
          %MediaPieceType{}
          |> MediaPieceType.changeset(%{
            name: type_name,
            desc: type_name,
            ad_phase_count_to_complete: 1,
            base_fee: Decimal.new("0.10"),
            markup_multiplier: Decimal.new("1.5")
          })
          |> Repo.insert!()

        existing ->
          existing
      end

    user = AccountsFixtures.user_fixture()
    me_file = user.me_file

    marketer =
      %Marketer{}
      |> Marketer.changeset(%{business_name: "Test Marketer #{System.unique_integer()}"})
      |> Repo.insert!()

    campaign =
      %Campaign{}
      |> Campaign.changeset(%{
        marketer_id: marketer.id,
        title: "Test Campaign",
        is_payable: true,
        is_throttled: false,
        is_demo: false
      })
      |> Repo.insert!()

    media_piece =
      %MediaPiece{}
      |> MediaPiece.changeset(%{
        title: "Test Ad",
        media_piece_type_id: mpt.id,
        marketer_id: marketer.id,
        active: true
      })
      |> Repo.insert!()

    case Repo.get(LedgerHeader, 1) do
      nil ->
        %LedgerHeader{id: 1, description: "Sponster", balance: Decimal.new(0)}
        |> Ecto.Changeset.change()
        |> Repo.insert!()

      _ ->
        :ok
    end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %AdEvent{}
    |> AdEvent.changeset(%{
      offer_bid_amt: Decimal.new("0.10"),
      is_throttled: false,
      is_offer_complete: false,
      ip_address: "127.0.0.1",
      url: "https://example.com",
      offer_id: 1,
      me_file_id: me_file.id,
      campaign_id: campaign.id,
      media_run_id: 1,
      media_piece_id: media_piece.id,
      media_piece_phase_id: 1,
      target_band_id: 1,
      is_payable: true,
      offer_marketer_cost_amt: Decimal.new("0.15"),
      event_marketer_cost_amt: Decimal.new("0.15"),
      event_me_file_collect_amt: Decimal.new("0.05"),
      event_sponster_collect_amt: sponster_amt,
      matching_tags_snapshot: %{}
    })
    |> Ecto.Changeset.put_change(:created_at, now)
    |> Ecto.Changeset.put_change(:updated_at, now)
    |> Repo.insert!()
  end
end
