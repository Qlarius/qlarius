defmodule Qlarius.AdminApi.PtpCoverage do
  @moduledoc """
  Read-only coverage of PTP campaigns for one month.

  Scope comes from the area segment of each campaign's api_ref. Throttle-blocked
  users currently hold a pending throttled PTP offer, which is the queue the
  global cap holds back.
  """

  import Ecto.Query

  alias Qlarius.ApiRef
  alias Qlarius.Repo
  alias Qlarius.System
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Sponster.Campaigns.Campaign

  def report(month) do
    with {:ok, start, stop} <- month_range(month || current_month()) do
      delivered = delivered_rows(start, stop)
      pending = pending_rows()

      by_user = Enum.frequencies_by(delivered, fn {me_file_id, _ref, _band} -> me_file_id end)
      offered = pending |> Enum.map(& &1.me_file_id) |> MapSet.new()
      seen = by_user |> Map.keys() |> MapSet.new()
      users = MapSet.union(offered, seen) |> MapSet.size()
      counts = Enum.map(users_list(offered, by_user), fn id -> Map.get(by_user, id, 0) end)

      {:ok,
       %{
         month: month || current_month(),
         users: users,
         delivered_ads: length(delivered),
         per_user: distribution(counts),
         by_scope: group_scope(delivered),
         by_campaign: group_campaign(delivered),
         by_band: group_band(delivered),
         pending_offers: length(pending),
         throttle_blocked_users: throttle_blocked()
       }}
    end
  end

  defp delivered_rows(start, stop) do
    from(ae in AdEvent,
      join: c in Campaign,
      on: c.id == ae.campaign_id,
      where: c.is_ptp == true and ae.created_at >= ^start and ae.created_at < ^stop,
      select: {ae.me_file_id, c.api_ref, ae.target_band_id}
    )
    |> Repo.all()
  end

  defp pending_rows do
    from(o in Offer,
      join: c in Campaign,
      on: c.id == o.campaign_id,
      where: c.is_ptp == true and o.is_current == false,
      select: %{me_file_id: o.me_file_id, is_throttled: o.is_throttled}
    )
    |> Repo.all()
  end

  defp users_list(offered, by_user) do
    offered |> MapSet.union(MapSet.new(Map.keys(by_user))) |> MapSet.to_list()
  end

  defp distribution([]), do: %{median: 0, at_least_10: 0, at_zero: 0}

  defp distribution(counts) do
    sorted = Enum.sort(counts)
    n = length(sorted)

    %{
      median: Enum.at(sorted, div(n - 1, 2)),
      at_least_10: Enum.count(sorted, &(&1 >= 10)) / n,
      at_zero: Enum.count(sorted, &(&1 == 0)) / n
    }
  end

  defp group_scope(rows) do
    rows
    |> Enum.group_by(fn {_id, ref, _band} -> ApiRef.scope(ref) end)
    |> Map.new(fn {scope, items} -> {scope, length(items)} end)
  end

  defp group_campaign(rows) do
    rows
    |> Enum.group_by(fn {_id, ref, _band} -> ref end)
    |> Map.new(fn {ref, items} -> {ref, length(items)} end)
  end

  defp group_band(rows) do
    rows
    |> Enum.group_by(fn {_id, _ref, band} -> band end)
    |> Map.new(fn {band, items} -> {band, length(items)} end)
  end

  defp month_range(month) do
    case Regex.run(~r/\A(\d{4})-(\d{2})\z/, to_string(month) || "", capture: :all_but_first) do
      [year, mon] ->
        {:ok, date} = Date.new(String.to_integer(year), String.to_integer(mon), 1)
        start = NaiveDateTime.new!(date, ~T[00:00:00])
        stop = NaiveDateTime.new!(Date.add(date, Date.days_in_month(date)), ~T[00:00:00])
        {:ok, start, stop}

      _ ->
        {:error, :invalid_month}
    end
  end

  defp throttle_blocked do
    cap = System.get_global_variable_int("THROTTLE_AD_COUNT", 3)
    days = System.get_global_variable_int("THROTTLE_DAYS", 7)

    since =
      NaiveDateTime.add(
        NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        -days * 86_400,
        :second
      )

    waiting =
      from(o in Offer,
        join: c in Campaign,
        on: c.id == o.campaign_id,
        where: c.is_ptp == true and o.is_current == false and o.is_throttled == true,
        distinct: true,
        select: o.me_file_id
      )
      |> Repo.all()

    if waiting == [] do
      0
    else
      from(ae in AdEvent,
        where: ae.me_file_id in ^waiting and ae.is_throttled == true and ae.created_at >= ^since,
        group_by: ae.me_file_id,
        having: count(ae.id) >= ^cap,
        select: ae.me_file_id
      )
      |> Repo.all()
      |> length()
    end
  end

  defp current_month do
    date = Date.utc_today()
    :io_lib.format("~4..0B-~2..0B", [date.year, date.month]) |> IO.iodata_to_binary()
  end
end
