defmodule Qlarius.Sponster.WidgetServeReporting do
  @moduledoc """
  Reports over `sponster_widget_serve_logs` for the admin dashboard.

  Every report takes a `{start_at, end_at}` range and a filter map that may
  hold `:recipient_id`, `:host`, `:ip`, `:page_load_id`, and `:flag`.

  Suspicious-activity flags are computed per row in SQL, inside the range
  and filters being viewed:

    * `burst` - one IP and one recipient with more than 30 loads in a
      10-minute bucket.
    * `page_id_churn` - one IP with more than 10 distinct page ids in an
      hour: reloads that each mint a new page.
    * `shared_page_id` - one page id seen from more than 3 IPs.
    * `reconnect_storm` - more than 20 connects on one page load.
    * `bot_agent` - an automation user agent, or no user agent on a load
      that came through the embed script (legacy rows had none).
    * `bad_host` - no publisher page, or a Qadabra page posing as one.
  """

  alias Qlarius.Repo
  alias Qlarius.Sponster.WidgetServeLogs.UserAgent

  @burst_loads 30
  @churn_pages 10
  @shared_ips 3
  @reconnects 20
  @list_limit 50

  @flags ~w(burst page_id_churn shared_page_id reconnect_storm bot_agent bad_host)a
  @periods %{"24h" => 1, "7d" => 7, "30d" => 30, "90d" => 90}

  def flags, do: @flags

  def thresholds do
    %{
      burst: @burst_loads,
      page_id_churn: @churn_pages,
      shared_page_id: @shared_ips,
      reconnect_storm: @reconnects
    }
  end

  def periods,
    do: [
      {"24h", "Last 24 hours"},
      {"7d", "Last 7 days"},
      {"30d", "Last 30 days"},
      {"90d", "Last 90 days"}
    ]

  def default_period, do: "7d"

  def period_to_range(period, now \\ NaiveDateTime.utc_now()) do
    days = Map.get(@periods, period, @periods[default_period()])
    now = NaiveDateTime.truncate(now, :second)
    {NaiveDateTime.add(now, -days * 86_400, :second), now}
  end

  @doc "Headline numbers for the range."
  def kpis(range, filters \\ %{}) do
    sql = """
    SELECT
      count(*),
      coalesce(sum(connect_count - 1), 0),
      count(DISTINCT page_load_id),
      count(DISTINCT ip_address),
      count(*) FILTER (WHERE authed),
      count(DISTINCT recipient_id),
      count(DISTINCT host),
      count(*) FILTER (WHERE host IS NULL),
      count(*) FILTER (WHERE #{any_flag()})
    FROM flagged
    """

    [[loads, reconnects, pages, ips, authed, recipients, hosts, direct, flagged]] =
      run(sql, range, filters)

    %{
      loads: loads,
      reconnects: to_int(reconnects),
      unique_pages: pages,
      unique_ips: ips,
      authed: authed,
      authed_share: share(authed, loads),
      recipients: recipients,
      hosts: hosts,
      direct_opens: direct,
      flagged: flagged,
      flagged_share: share(flagged, loads)
    }
  end

  @doc "Loads per hour or day, split into signed-in, anonymous, and flagged."
  def time_series(range, bucket, filters \\ %{}) when bucket in [:hour, :day] do
    sql = """
    SELECT
      date_trunc('#{bucket}', created_at) AS bucket,
      count(*) FILTER (WHERE authed),
      count(*) FILTER (WHERE NOT authed),
      count(*) FILTER (WHERE #{any_flag()})
    FROM flagged
    GROUP BY 1
    ORDER BY 1
    """

    found =
      run(sql, range, filters)
      |> Map.new(fn [at, authed, anon, flagged] ->
        {at, %{authed: authed, anon: anon, flagged: flagged}}
      end)

    range
    |> buckets(bucket)
    |> Enum.map(fn at ->
      counts = Map.get(found, at, %{authed: 0, anon: 0, flagged: 0})
      Map.merge(counts, %{at: at, total: counts.authed + counts.anon})
    end)
  end

  @doc "One row per recipient, busiest first."
  def by_recipient(range, filters \\ %{}) do
    sql = """
    SELECT
      f.recipient_id,
      #{recipient_name_sql()},
      count(*),
      count(DISTINCT f.page_load_id),
      count(DISTINCT f.ip_address),
      count(*) FILTER (WHERE f.authed),
      count(DISTINCT f.host),
      count(*) FILTER (WHERE #{any_flag("f.")}),
      max(f.created_at)
    FROM flagged f
    LEFT JOIN recipients r ON r.id = f.recipient_id
    GROUP BY 1, 2
    ORDER BY 3 DESC
    """

    run(sql, range, filters)
    |> Enum.map(fn [id, name, loads, pages, ips, authed, hosts, flagged, last] ->
      %{
        recipient_id: id,
        name: name,
        loads: loads,
        unique_pages: pages,
        unique_ips: ips,
        authed_share: share(authed, loads),
        loads_per_ip: ratio(loads, ips),
        hosts: hosts,
        flagged: flagged,
        flagged_share: share(flagged, loads),
        last_seen: last
      }
    end)
  end

  @doc "One row per publisher host, busiest first."
  def by_host(range, filters \\ %{}) do
    sql = """
    SELECT
      f.host,
      count(*),
      count(DISTINCT f.page_load_id),
      count(DISTINCT f.ip_address),
      count(*) FILTER (WHERE f.authed),
      count(DISTINCT f.recipient_id),
      count(*) FILTER (WHERE #{any_flag("f.")}),
      max(f.created_at)
    FROM flagged f
    GROUP BY f.host
    ORDER BY 2 DESC
    LIMIT 200
    """

    run(sql, range, filters)
    |> Enum.map(fn [host, loads, pages, ips, authed, recipients, flagged, last] ->
      %{
        host: host,
        loads: loads,
        unique_pages: pages,
        unique_ips: ips,
        authed_share: share(authed, loads),
        loads_per_ip: ratio(loads, ips),
        recipients: recipients,
        flagged: flagged,
        flagged_share: share(flagged, loads),
        last_seen: last
      }
    end)
  end

  @doc """
  Load counts per device class. Legacy rows kept the raw user agent in
  `device`, so classification runs on whichever agent string a row has.
  """
  def by_device(range, filters \\ %{}) do
    sql = """
    SELECT #{agent_sql()}, count(*)
    FROM flagged
    GROUP BY 1
    """

    run(sql, range, filters)
    |> Enum.group_by(fn [ua, _] -> UserAgent.device(ua) || "Unknown" end, fn [_, n] -> n end)
    |> Enum.map(fn {device, counts} -> %{device: device, loads: Enum.sum(counts)} end)
    |> Enum.sort_by(& &1.loads, :desc)
  end

  defp agent_sql(prefix \\ ""), do: "coalesce(#{prefix}user_agent, #{prefix}device)"

  defp recipient_name_sql do
    "CASE WHEN f.recipient_id IS NULL THEN '(no recipient)' " <>
      "ELSE coalesce(r.name, '(deleted recipient)') END"
  end

  @doc """
  Suspicious activity grouped by rule. Each entry names its subject and the
  log filter that shows the rows behind it.
  """
  def suspicious(range, filters \\ %{}) do
    Enum.flat_map(@flags, &suspicious_for(&1, range, filters))
  end

  defp suspicious_for(:burst, range, filters) do
    """
    SELECT f.ip_address, f.recipient_id, #{recipient_name_sql()},
           count(*), min(f.created_at), max(f.created_at)
    FROM flagged f
    LEFT JOIN recipients r ON r.id = f.recipient_id
    WHERE f.burst
    GROUP BY 1, 2, 3
    ORDER BY 4 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn [ip, recipient_id, name, count, first, last] ->
      entry(:burst, "#{ip} on #{name}", count, first, last, %{ip: ip, recipient_id: recipient_id})
    end)
  end

  defp suspicious_for(:page_id_churn, range, filters) do
    """
    SELECT f.ip_address, count(*), count(DISTINCT f.page_load_id), min(f.created_at), max(f.created_at)
    FROM flagged f
    WHERE f.page_id_churn
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn [ip, count, pages, first, last] ->
      entry(:page_id_churn, "#{ip} (#{pages} page ids)", count, first, last, %{ip: ip})
    end)
  end

  defp suspicious_for(:shared_page_id, range, filters) do
    """
    SELECT f.page_load_id, count(*), count(DISTINCT f.ip_address), min(f.created_at), max(f.created_at)
    FROM flagged f
    WHERE f.shared_page_id
    GROUP BY 1
    ORDER BY 3 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn [page_id, count, ips, first, last] ->
      page_id = uuid(page_id)

      entry(:shared_page_id, "#{page_id} (#{ips} IPs)", count, first, last, %{
        page_load_id: page_id
      })
    end)
  end

  defp suspicious_for(:reconnect_storm, range, filters) do
    """
    SELECT f.page_load_id, f.ip_address, f.connect_count, f.created_at, f.updated_at
    FROM flagged f
    WHERE f.reconnect_storm
    ORDER BY 3 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn [page_id, ip, connects, first, last] ->
      page_id = uuid(page_id)

      entry(:reconnect_storm, "#{ip} page #{page_id}", connects, first, last, %{
        page_load_id: page_id
      })
    end)
  end

  defp suspicious_for(:bot_agent, range, filters) do
    """
    SELECT coalesce(#{agent_sql("f.")}, '(missing)'), count(*), min(f.created_at), max(f.created_at)
    FROM flagged f
    WHERE f.bot_agent
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn [ua, count, first, last] ->
      entry(:bot_agent, String.slice(ua, 0, 160), count, first, last, %{flag: :bot_agent})
    end)
  end

  defp suspicious_for(:bad_host, range, filters) do
    """
    SELECT f.host, count(*), min(f.created_at), max(f.created_at)
    FROM flagged f
    WHERE f.bad_host
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT #{@list_limit}
    """
    |> run(range, filters)
    |> Enum.map(fn
      [nil, count, first, last] ->
        entry(:bad_host, "No publisher page", count, first, last, %{flag: :bad_host})

      [host, count, first, last] ->
        entry(:bad_host, host, count, first, last, %{host: host})
    end)
  end

  defp entry(kind, subject, count, first, last, filter) do
    %{
      kind: kind,
      subject: subject,
      count: count,
      first_seen: first,
      last_seen: last,
      filter: filter
    }
  end

  @doc "Raw rows, newest first, with the flags each row hits."
  def recent(range, filters \\ %{}, page \\ 1, per_page \\ 50) do
    offset = (max(page, 1) - 1) * per_page

    sql = """
    SELECT f.id, f.created_at, f.recipient_id, #{recipient_name_sql()}, f.host,
           f.host_page_url, f.ip_address, f.authed, f.connect_count, #{agent_sql("f.")},
           f.page_load_id, #{Enum.map_join(@flags, ", ", &"f.#{&1}")}
    FROM flagged f
    LEFT JOIN recipients r ON r.id = f.recipient_id
    ORDER BY f.created_at DESC, f.id DESC
    LIMIT #{per_page} OFFSET #{offset}
    """

    rows =
      run(sql, range, filters)
      |> Enum.map(fn [
                       id,
                       at,
                       recipient_id,
                       name,
                       host,
                       url,
                       ip,
                       authed,
                       connects,
                       ua,
                       page_id | flags
                     ] ->
        %{
          id: id,
          created_at: at,
          recipient_id: recipient_id,
          recipient_name: name,
          host: host,
          host_page_url: url,
          ip_address: ip,
          authed: authed,
          connect_count: connects,
          user_agent: ua,
          device: UserAgent.device(ua),
          page_load_id: uuid(page_id),
          flags: @flags |> Enum.zip(flags) |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0))
        }
      end)

    [[total]] = run("SELECT count(*) FROM flagged", range, filters)

    %{rows: rows, total: total, page: max(page, 1), per_page: per_page}
  end

  # Every report reads from the `flagged` CTE: the rows in range and filters,
  # each with one boolean column per rule.
  defp run(select_sql, {start_at, end_at}, filters) do
    {where, params} = filter_sql(filters, [start_at, end_at])
    {flag_where, params} = flag_filter(filters, params)

    sql = """
    WITH scoped AS (
      SELECT * FROM sponster_widget_serve_logs
      WHERE created_at >= $1 AND created_at < $2#{where}
    ),
    bursts AS (
      SELECT ip_address, recipient_id, floor(extract(epoch FROM created_at) / 600) AS slot
      FROM scoped
      WHERE ip_address IS NOT NULL
      GROUP BY 1, 2, 3
      HAVING count(*) > #{@burst_loads}
    ),
    churn AS (
      SELECT ip_address, date_trunc('hour', created_at) AS hour
      FROM scoped
      WHERE ip_address IS NOT NULL AND page_load_id IS NOT NULL
      GROUP BY 1, 2
      HAVING count(DISTINCT page_load_id) > #{@churn_pages}
    ),
    shared AS (
      SELECT page_load_id
      FROM scoped
      WHERE page_load_id IS NOT NULL
      GROUP BY 1
      HAVING count(DISTINCT ip_address) > #{@shared_ips}
    ),
    all_flagged AS (
      SELECT s.*,
        (b.ip_address IS NOT NULL) AS burst,
        (c.ip_address IS NOT NULL) AS page_id_churn,
        (sh.page_load_id IS NOT NULL) AS shared_page_id,
        (s.connect_count > #{@reconnects}) AS reconnect_storm,
        (coalesce(#{agent_sql("s.")} ~* '#{UserAgent.bot_pattern_sql()}', false)
          OR (s.user_agent IS NULL AND s.page_load_id IS NOT NULL)) AS bot_agent,
        (s.host IS NULL OR s.host = 'qadabra.app' OR s.host LIKE '%.qadabra.app') AS bad_host
      FROM scoped s
      LEFT JOIN bursts b
        ON b.ip_address = s.ip_address
        AND b.recipient_id IS NOT DISTINCT FROM s.recipient_id
        AND b.slot = floor(extract(epoch FROM s.created_at) / 600)
      LEFT JOIN churn c
        ON c.ip_address = s.ip_address AND c.hour = date_trunc('hour', s.created_at)
      LEFT JOIN shared sh ON sh.page_load_id = s.page_load_id
    ),
    flagged AS (
      SELECT * FROM all_flagged#{flag_where}
    )
    #{select_sql}
    """

    Repo.query!(sql, params).rows
  end

  defp filter_sql(filters, params) do
    [
      {:recipient_id, "recipient_id"},
      {:host, "host"},
      {:ip, "ip_address"},
      {:page_load_id, "page_load_id"}
    ]
    |> Enum.reduce({"", params}, fn {key, column}, {sql, params} ->
      case filter_value(key, Map.get(filters, key)) do
        nil -> {sql, params}
        value -> {sql <> " AND #{column} = $#{length(params) + 1}", params ++ [value]}
      end
    end)
  end

  defp filter_value(_key, nil), do: nil
  defp filter_value(_key, ""), do: nil
  defp filter_value(:recipient_id, id) when is_integer(id), do: id

  defp filter_value(:recipient_id, id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp filter_value(:page_load_id, id) when is_binary(id) do
    case Ecto.UUID.dump(id) do
      {:ok, binary} -> binary
      :error -> nil
    end
  end

  defp filter_value(_key, value) when is_binary(value), do: value
  defp filter_value(_key, _value), do: nil

  defp flag_filter(filters, params) do
    case Map.get(filters, :flag) do
      flag when flag in @flags -> {" WHERE #{flag}", params}
      "any" -> {" WHERE #{any_flag()}", params}
      :any -> {" WHERE #{any_flag()}", params}
      _ -> {"", params}
    end
  end

  defp any_flag(prefix \\ ""), do: Enum.map_join(@flags, " OR ", &"#{prefix}#{&1}")

  defp buckets({start_at, end_at}, bucket) do
    step = if bucket == :hour, do: 3_600, else: 86_400
    first = truncate(start_at, bucket)

    first
    |> Stream.iterate(&NaiveDateTime.add(&1, step, :second))
    |> Enum.take_while(&(NaiveDateTime.compare(&1, end_at) != :gt))
  end

  defp truncate(%NaiveDateTime{} = at, :hour),
    do: %{at | minute: 0, second: 0, microsecond: {0, 6}}

  defp truncate(%NaiveDateTime{} = at, :day),
    do: %{at | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}

  defp uuid(nil), do: nil
  defp uuid(<<_::128>> = binary), do: Ecto.UUID.load!(binary)
  defp uuid(value), do: value

  defp share(_part, 0), do: 0.0
  defp share(part, total), do: part / total

  defp ratio(_loads, 0), do: 0.0
  defp ratio(loads, ips), do: Float.round(loads / ips, 1)

  defp to_int(%Decimal{} = d), do: Decimal.to_integer(d)
  defp to_int(n) when is_integer(n), do: n
  defp to_int(_), do: 0
end
