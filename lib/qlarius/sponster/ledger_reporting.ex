defmodule Qlarius.Sponster.LedgerReporting do
  @moduledoc """
  Aggregates Sponster revenue and ad activity from `ad_events` for the admin dashboard.
  """

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.{MediaPiece, MediaPieceType}
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Accounts.Marketer
  alias Qlarius.Wallets

  @default_period "30d"

  def default_period, do: @default_period

  @doc """
  Resolves a period key to `{start_at, end_at}` naive datetimes (UTC).
  Returns `{nil, nil}` for `"all"` (no date filter).
  """
  def period_to_range("7d"), do: {days_ago(7), now()}
  def period_to_range("30d"), do: {days_ago(30), now()}
  def period_to_range("90d"), do: {days_ago(90), now()}
  def period_to_range("all"), do: {nil, nil}
  def period_to_range(_), do: period_to_range(@default_period)

  @doc """
  Headline KPIs for the selected period. Revenue sums exclude demo events.
  """
  def summary_stats(start_at, end_at) do
    base = range_query(start_at, end_at)
    revenue_base = from(ae in base, where: ae.is_demo == false)

    %{
      ledger_balance: ledger_balance(),
      sponster_revenue: sum_decimal(revenue_base, :event_sponster_collect_amt, payable: true),
      ad_events: count_rows(base),
      payable_events: count_rows(from(ae in base, where: ae.is_payable == true)),
      demo_events: count_rows(from(ae in base, where: ae.is_demo == true)),
      throttled_events: count_rows(from(ae in base, where: ae.is_throttled == true)),
      marketer_spend: sum_decimal(revenue_base, :event_marketer_cost_amt),
      consumer_payouts: sum_decimal(revenue_base, :event_me_file_collect_amt),
      recipient_payouts: recipient_payouts_sum(revenue_base),
      unique_consumers: count_distinct(revenue_base, :me_file_id),
      # Successful engagement completions only — exclude banner-max exhausted attempts.
      offer_completions:
        count_rows(
          from(ae in base,
            where:
              ae.is_offer_complete == true and
                (is_nil(ae.completion_kind) or ae.completion_kind == "full_funnel")
          )
        )
    }
    |> Map.put(
      :avg_revenue_per_payable,
      avg_revenue_per_payable(revenue_base)
    )
  end

  @doc """
  Time-bucketed activity. `bucket` is `:day`, `:week`, or `:month`.
  """
  def time_series(start_at, end_at, bucket) when bucket in [:day, :week, :month] do
    base = from(ae in range_query(start_at, end_at), where: ae.is_demo == false)

    query =
      case bucket do
        :day -> time_series_query(base, "day")
        :week -> time_series_query(base, "week")
        :month -> time_series_query(base, "month")
      end

    query
    |> Repo.all()
    |> Enum.map(&normalize_series_row/1)
  end

  defp time_series_query(base, "day") do
    from ae in base,
      group_by: fragment("date_trunc('day', ?)", ae.created_at),
      order_by: [asc: fragment("date_trunc('day', ?)", ae.created_at)],
      select: %{
        period: fragment("date_trunc('day', ?)", ae.created_at),
        events: count(ae.id),
        sponster_revenue: sum(ae.event_sponster_collect_amt),
        marketer_cost: sum(ae.event_marketer_cost_amt),
        consumer_collect: sum(ae.event_me_file_collect_amt)
      }
  end

  defp time_series_query(base, "week") do
    from ae in base,
      group_by: fragment("date_trunc('week', ?)", ae.created_at),
      order_by: [asc: fragment("date_trunc('week', ?)", ae.created_at)],
      select: %{
        period: fragment("date_trunc('week', ?)", ae.created_at),
        events: count(ae.id),
        sponster_revenue: sum(ae.event_sponster_collect_amt),
        marketer_cost: sum(ae.event_marketer_cost_amt),
        consumer_collect: sum(ae.event_me_file_collect_amt)
      }
  end

  defp time_series_query(base, "month") do
    from ae in base,
      group_by: fragment("date_trunc('month', ?)", ae.created_at),
      order_by: [asc: fragment("date_trunc('month', ?)", ae.created_at)],
      select: %{
        period: fragment("date_trunc('month', ?)", ae.created_at),
        events: count(ae.id),
        sponster_revenue: sum(ae.event_sponster_collect_amt),
        marketer_cost: sum(ae.event_marketer_cost_amt),
        consumer_collect: sum(ae.event_me_file_collect_amt)
      }
  end

  @doc """
  Revenue breakdown grouped by `media_piece_types.name`.
  """
  def revenue_by_ad_unit_type(start_at, end_at) do
    rows =
      from(ae in range_query(start_at, end_at),
        join: mp in MediaPiece,
        on: ae.media_piece_id == mp.id,
        join: mpt in MediaPieceType,
        on: mp.media_piece_type_id == mpt.id,
        where: ae.is_demo == false and ae.is_payable == true,
        group_by: mpt.id,
        order_by: [desc: sum(ae.event_sponster_collect_amt)],
        select: %{
          ad_unit_type: mpt.name,
          events: count(ae.id),
          revenue: sum(ae.event_sponster_collect_amt)
        }
      )
      |> Repo.all()

    total_revenue =
      rows
      |> Enum.reduce(Decimal.new(0), fn row, acc ->
        Decimal.add(acc, row.revenue || Decimal.new(0))
      end)

    Enum.map(rows, fn row ->
      revenue = row.revenue || Decimal.new(0)
      events = row.events || 0

      %{
        ad_unit_type: row.ad_unit_type,
        events: events,
        revenue: revenue,
        avg_per_event: avg_decimal(revenue, events),
        pct_of_revenue: pct_of(revenue, total_revenue)
      }
    end)
  end

  def top_marketers(start_at, end_at, limit \\ 10) do
    from(ae in range_query(start_at, end_at),
      join: c in Campaign,
      on: ae.campaign_id == c.id,
      join: m in Marketer,
      on: c.marketer_id == m.id,
      where: ae.is_demo == false and ae.is_payable == true,
      group_by: [m.id, m.business_name],
      order_by: [desc: sum(ae.event_sponster_collect_amt)],
      limit: ^limit,
      select: %{
        marketer_id: m.id,
        marketer_name: m.business_name,
        events: count(ae.id),
        revenue: sum(ae.event_sponster_collect_amt)
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | revenue: row.revenue || Decimal.new(0)}
    end)
  end

  def top_campaigns(start_at, end_at, limit \\ 10) do
    from(ae in range_query(start_at, end_at),
      join: c in Campaign,
      on: ae.campaign_id == c.id,
      where: ae.is_demo == false and ae.is_payable == true,
      group_by: [c.id, c.title],
      order_by: [desc: sum(ae.event_sponster_collect_amt)],
      limit: ^limit,
      select: %{
        campaign_id: c.id,
        campaign_title: c.title,
        events: count(ae.id),
        revenue: sum(ae.event_sponster_collect_amt)
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | revenue: row.revenue || Decimal.new(0)}
    end)
  end

  def recent_events(start_at, end_at, limit \\ 20) do
    from(ae in range_query(start_at, end_at),
      join: mp in MediaPiece,
      on: ae.media_piece_id == mp.id,
      join: mpt in MediaPieceType,
      on: mp.media_piece_type_id == mpt.id,
      join: c in Campaign,
      on: ae.campaign_id == c.id,
      join: m in Marketer,
      on: c.marketer_id == m.id,
      where: ae.is_payable == true,
      order_by: [desc: ae.created_at],
      limit: ^limit,
      select: %{
        id: ae.id,
        created_at: ae.created_at,
        marketer_name: m.business_name,
        campaign_title: c.title,
        ad_unit_type: mpt.name,
        sponster_revenue: ae.event_sponster_collect_amt,
        consumer_collect: ae.event_me_file_collect_amt,
        marketer_cost: ae.event_marketer_cost_amt,
        is_demo: ae.is_demo
      }
    )
    |> Repo.all()
  end

  defp range_query(nil, nil) do
    AdEvent
  end

  defp range_query(start_at, end_at) do
    from(ae in AdEvent,
      where: ae.created_at >= ^start_at and ae.created_at <= ^end_at
    )
  end

  defp ledger_balance do
    case Wallets.sponster_ledger_header() do
      nil -> Decimal.new(0)
      header -> header.balance || Decimal.new(0)
    end
  end

  defp sum_decimal(query, field, opts \\ []) do
    q =
      if Keyword.get(opts, :payable, false) do
        from(ae in query, where: ae.is_payable == true)
      else
        query
      end

    from(ae in q, select: sum(field(ae, ^field)))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      amount -> amount
    end
  end

  defp recipient_payouts_sum(query) do
    from(ae in query,
      select:
        sum(
          fragment(
            "COALESCE(?, 0) + COALESCE(?, 0)",
            ae.event_recipient_collect_amt,
            ae.event_sponster_to_recipient_amt
          )
        )
    )
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      amount -> amount
    end
  end

  defp count_rows(query) do
    from(ae in query, select: count(ae.id))
    |> Repo.one() || 0
  end

  defp count_distinct(query, field) do
    from(ae in query, select: count(fragment("DISTINCT ?", field(ae, ^field))))
    |> Repo.one() || 0
  end

  defp avg_revenue_per_payable(query) do
    payable_q = from(ae in query, where: ae.is_payable == true)

    revenue =
      from(ae in payable_q, select: sum(ae.event_sponster_collect_amt))
      |> Repo.one()

    count =
      from(ae in payable_q, select: count(ae.id))
      |> Repo.one() || 0

    avg_decimal(revenue, count)
  end

  defp avg_decimal(nil, _), do: Decimal.new(0)
  defp avg_decimal(_, 0), do: Decimal.new(0)

  defp avg_decimal(amount, count) when is_integer(count) and count > 0 do
    amount
    |> Decimal.div(Decimal.new(count))
    |> Decimal.round(2)
  end

  defp pct_of(_revenue, nil), do: 0.0

  defp pct_of(revenue, total) do
    if total == nil or Decimal.compare(total, Decimal.new(0)) != :gt do
      0.0
    else
      revenue
      |> Decimal.div(total)
      |> Decimal.mult(Decimal.new(100))
      |> Decimal.to_float()
      |> Float.round(1)
    end
  end

  defp normalize_series_row(row) do
    %{
      period: row.period,
      events: row.events || 0,
      sponster_revenue: row.sponster_revenue || Decimal.new(0),
      marketer_cost: row.marketer_cost || Decimal.new(0),
      consumer_collect: row.consumer_collect || Decimal.new(0)
    }
  end

  defp days_ago(n) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-n * 24 * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end

  defp now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end
end
