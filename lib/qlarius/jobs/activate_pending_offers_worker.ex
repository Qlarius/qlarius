defmodule Qlarius.Jobs.ActivatePendingOffersWorker do
  # One run at a time for as long as a job is queued or executing. A slow cycle
  # must not stack on the next cron tick and hold the database pool.
  #
  # Oban does not check out a connection for perform/1. Each Repo call checks
  # one out and returns it when that query finishes. A single unbounded UPDATE
  # or a lateral read across hundreds of MeFiles keeps that connection checked
  # out the whole time, and the shared pool then drops web requests (CoDel,
  # default queue interval 2s). Batches keep each checkout small. A run also
  # stops after @run_budget_ms so the rest waits for the next */5 tick.
  use Oban.Worker,
    queue: :activations,
    max_attempts: 1,
    unique: [
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable]
    ]

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.Offers
  alias Qlarius.Sponster.Campaigns.CampaignFilters
  alias Qlarius.Sponster.Campaigns.CampaignPubSub

  # Small enough that one statement returns its connection before the pool's
  # queue interval. The run budget leaves the rest of a backlog for the next tick.
  @batch_size 25
  @run_budget_ms 2_000
  @query_timeout_ms 5_000

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    require Logger
    Logger.info("📊 ActivatePendingOffersWorker: Starting activation cycle")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    started = System.monotonic_time(:millisecond)

    Logger.info("📊 Config: throttle limits are per MeFile")

    # Alternate which backlog goes first so a large unthrottled set cannot
    # spend the whole budget on every tick and leave throttled offers pending.
    {unthrottled_activated, throttled_activated, throttled_blocked, me_files_processed, deferred} =
      if rem(now.minute, 10) < 5 do
        unthrottled = activate_unthrottled_offers(now, started)
        {throttled, blocked, processed, deferred} = activate_throttled_offers(now, started)
        {unthrottled, throttled, blocked, processed, deferred}
      else
        {throttled, blocked, processed, deferred} = activate_throttled_offers(now, started)
        unthrottled = activate_unthrottled_offers(now, started)
        {unthrottled, throttled, blocked, processed, deferred}
      end

    if unthrottled_activated == 0 and throttled_activated == 0 and deferred == 0 do
      Logger.info(
        "ActivatePendingOffersWorker: nothing to activate " <>
          "(#{me_files_processed} throttled MeFiles, #{throttled_blocked} already at cap)"
      )
    end

    if deferred > 0 do
      Logger.warning(
        "ActivatePendingOffersWorker: deferred #{deferred} throttled MeFiles after #{@run_budget_ms}ms. " <>
          "The next cron tick continues them."
      )
    end

    # Summary log
    Logger.info("""
    📊 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📊 ACTIVATION CYCLE SUMMARY
    📊 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📊 Unthrottled offers activated: #{unthrottled_activated}
    📊 Throttled offers activated:   #{throttled_activated}
    📊 Total offers activated:       #{unthrottled_activated + throttled_activated}
    📊 ─────────────────────────────────────────────────────
    📊 MeFiles processed:            #{me_files_processed}
    📊 MeFiles blocked (throttled):  #{throttled_blocked}
    📊 MeFiles deferred:             #{deferred}
    📊 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)

    :ok
  end

  defp activate_unthrottled_offers(now, started) do
    require Logger

    total = activate_unthrottled_batch(now, started, 0)

    Logger.info("ActivatePendingOffersWorker: Activated #{total} unthrottled offers")

    if total > 0 do
      broadcast_activations()
    end

    total
  end

  defp activate_unthrottled_batch(now, started, total) do
    if over_budget?(started) do
      total
    else
      {count, _} =
        from(o in Offer, where: o.id in subquery(due_unthrottled_ids(now)))
        |> Repo.update_all([set: [is_current: true, updated_at: now]], timeout: @query_timeout_ms)

      if count == 0 do
        total
      else
        activate_unthrottled_batch(now, started, total + count)
      end
    end
  end

  defp due_unthrottled_ids(now) do
    from(o in Offer,
      join: c in assoc(o, :campaign),
      as: :campaign,
      where: o.is_current == false,
      where: o.is_throttled == false,
      where: o.pending_until <= ^now,
      order_by: [asc: o.id],
      limit: ^@batch_size,
      select: o.id
    )
    |> CampaignFilters.live_now(now)
  end

  defp activate_throttled_offers(now, started) do
    require Logger

    me_file_ids = now |> pending_throttled_me_file_ids() |> rotate(now)

    {activated, blocked, processed, deferred?} =
      Enum.reduce_while(Enum.chunk_every(me_file_ids, @batch_size), {0, 0, 0, false}, fn ids,
                                                                                         {activated,
                                                                                          blocked,
                                                                                          processed,
                                                                                          _} ->
        if over_budget?(started) and processed > 0 do
          {:halt, {activated, blocked, processed, true}}
        else
          budgets = Offers.throttle_budgets(ids, now)
          open = Enum.filter(ids, fn id -> budgets[id].remaining > 0 end)

          {:cont,
           {activated + activate_within_budget(open, budgets, now),
            blocked + (length(ids) - length(open)), processed + length(ids), false}}
        end
      end)

    deferred = if deferred?, do: length(me_file_ids) - processed, else: 0

    Logger.info(
      "ActivatePendingOffersWorker: #{length(me_file_ids)} MeFiles with due throttled offers, " <>
        "#{length(me_file_ids) - blocked - deferred} under their cap, #{deferred} deferred"
    )

    {activated, blocked, processed, deferred}
  end

  defp over_budget?(started) do
    System.monotonic_time(:millisecond) - started >= @run_budget_ms
  end

  # Spread a backlog across ticks. Capped MeFiles stay pending, so always
  # starting at the lowest id would rescan them and never reach the rest.
  defp rotate([], _now), do: []

  defp rotate(ids, now) do
    offset = rem(now.minute * 60 + now.second, length(ids))
    {head, tail} = Enum.split(ids, offset)
    tail ++ head
  end

  defp pending_throttled_me_file_ids(now) do
    from(o in Offer,
      join: c in assoc(o, :campaign),
      as: :campaign,
      where: o.is_current == false,
      where: o.is_throttled == true,
      where: o.pending_until <= ^now,
      distinct: true,
      order_by: [asc: o.me_file_id],
      select: o.me_file_id
    )
    |> CampaignFilters.live_now(now)
    |> Repo.all()
  end

  # One short read and one short update for this batch. The connection is
  # checked back in after each, before the next MeFile batch.
  defp activate_within_budget([], _budgets, _now), do: 0

  defp activate_within_budget(me_file_ids, budgets, now) do
    limits = Enum.map(me_file_ids, fn id -> {id, budgets[id].remaining} end)
    offers = due_offers_within_budget(limits, now)
    ids = Enum.map(offers, & &1.id)

    if ids == [] do
      0
    else
      {activated, _} =
        from(o in Offer, where: o.id in ^ids and o.is_current == false)
        |> Repo.update_all([set: [is_current: true, updated_at: now]], timeout: @query_timeout_ms)

      if activated > 0 do
        offers
        |> Enum.group_by(& &1.campaign_id)
        |> Enum.each(fn {campaign_id, rows} ->
          CampaignPubSub.broadcast_offers_created(campaign_id, length(rows))
        end)
      end

      activated
    end
  end

  # The campaign predicates match CampaignFilters.live_now/2. LIMIT is the
  # MeFile's remaining slots, so a capped MeFile never reaches this query.
  defp due_offers_within_budget(limits, now) do
    {ids, remainings} = Enum.unzip(limits)

    sql = """
    SELECT picked.id, picked.me_file_id, picked.campaign_id
    FROM unnest($1::int[], $2::int[]) AS lim(me_file_id, remaining)
    JOIN LATERAL (
      SELECT o.id, o.me_file_id, o.campaign_id
      FROM offers o
      INNER JOIN campaigns c ON c.id = o.campaign_id
      WHERE o.me_file_id = lim.me_file_id
        AND o.is_current = FALSE
        AND o.is_throttled = TRUE
        AND o.pending_until <= $3
        AND c.deactivated_at IS NULL
        AND c.launched_at IS NOT NULL
        AND (c.start_date IS NULL OR c.start_date <= $3)
        AND (c.end_date IS NULL OR c.end_date >= $3)
      ORDER BY o.pending_until, o.id
      LIMIT lim.remaining
    ) AS picked ON TRUE
    """

    %{rows: rows} = Repo.query!(sql, [ids, remainings, now], timeout: @query_timeout_ms)

    Enum.map(rows, fn [id, me_file_id, campaign_id] ->
      %{id: id, me_file_id: me_file_id, campaign_id: campaign_id}
    end)
  end

  defp broadcast_activations do
    CampaignPubSub.broadcast_offers_activated()
  end

  @telemetry_id "qlarius-activate-pending-offers-skip"

  @doc false
  def attach_skip_logger do
    :telemetry.detach(@telemetry_id)

    :telemetry.attach(
      @telemetry_id,
      [:oban, :plugin, :stop],
      &__MODULE__.handle_unique_skip/4,
      nil
    )
  end

  @doc false
  def handle_unique_skip(_event, _measure, %{plugin: Oban.Plugins.Cron, jobs: jobs}, _config) do
    Enum.each(jobs, &log_unique_skip/1)
  end

  def handle_unique_skip(_event, _measure, _meta, _config), do: :ok

  defp log_unique_skip(%{
         worker: "Qlarius.Jobs.ActivatePendingOffersWorker",
         conflict?: true,
         id: id,
         state: state
       }) do
    require Logger

    Logger.warning(
      "ActivatePendingOffersWorker: skipped, job #{id} is still #{state}. " <>
        "A new run waits until that row leaves #{state}; Lifeline discards a stuck executing job 30 minutes after it started."
    )
  end

  defp log_unique_skip(_job), do: :ok
end
