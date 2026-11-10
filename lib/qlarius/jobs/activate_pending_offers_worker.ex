defmodule Qlarius.Jobs.ActivatePendingOffersWorker do
  # One run at a time for as long as a job is queued or executing. A slow cycle
  # must not stack on the next cron tick and hold the database pool.
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

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    require Logger
    Logger.info("📊 ActivatePendingOffersWorker: Starting activation cycle")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Get counts before activation for summary
    pending_unthrottled = count_pending_unthrottled_offers(now)
    pending_throttled = count_pending_throttled_offers(now)

    Logger.info("📊 Config: throttle limits are per MeFile")

    Logger.info(
      "📊 Pending offers: #{pending_unthrottled} unthrottled, #{pending_throttled} throttled"
    )

    unthrottled_activated = activate_unthrottled_offers(now)

    {throttled_activated, throttled_blocked, me_files_processed} =
      activate_throttled_offers(now)

    if unthrottled_activated == 0 and throttled_activated == 0 do
      Logger.info(
        "ActivatePendingOffersWorker: nothing to activate " <>
          "(#{pending_unthrottled} unthrottled due, #{me_files_processed} throttled MeFiles, #{throttled_blocked} already at cap)"
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
    📊 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)

    :ok
  end

  defp count_pending_unthrottled_offers(now) do
    from(o in Offer,
      join: c in assoc(o, :campaign),
      as: :campaign,
      where: o.is_current == false,
      where: o.is_throttled == false,
      where: o.pending_until <= ^now,
      select: count(o.id)
    )
    |> CampaignFilters.live_now(now)
    |> Repo.one()
  end

  defp count_pending_throttled_offers(now) do
    from(o in Offer,
      join: c in assoc(o, :campaign),
      as: :campaign,
      where: o.is_current == false,
      where: o.is_throttled == true,
      where: o.pending_until <= ^now,
      select: count(o.id)
    )
    |> CampaignFilters.live_now(now)
    |> Repo.one()
  end

  defp activate_unthrottled_offers(now) do
    require Logger

    {count, _} =
      from(o in Offer,
        join: c in assoc(o, :campaign),
        as: :campaign,
        where: o.is_current == false,
        where: o.is_throttled == false,
        where: o.pending_until <= ^now
      )
      |> CampaignFilters.live_now(now)
      |> Repo.update_all(set: [is_current: true, updated_at: now])

    Logger.info("ActivatePendingOffersWorker: Activated #{count} unthrottled offers")

    if count > 0 do
      broadcast_activations()
    end

    count
  end

  defp activate_throttled_offers(now) do
    require Logger

    me_file_ids = pending_throttled_me_file_ids(now)
    budgets = Offers.throttle_budgets(me_file_ids, now)
    open = Enum.filter(me_file_ids, fn id -> budgets[id].remaining > 0 end)

    Logger.info(
      "ActivatePendingOffersWorker: #{length(me_file_ids)} MeFiles with due throttled offers, #{length(open)} under their cap"
    )

    activated =
      open
      |> Enum.chunk_every(500)
      |> Enum.reduce(0, fn ids, acc -> acc + activate_within_budget(ids, budgets, now) end)

    {activated, length(me_file_ids) - length(open), length(me_file_ids)}
  end

  defp pending_throttled_me_file_ids(now) do
    from(o in Offer,
      join: c in assoc(o, :campaign),
      as: :campaign,
      where: o.is_current == false,
      where: o.is_throttled == true,
      where: o.pending_until <= ^now,
      distinct: true,
      select: o.me_file_id
    )
    |> CampaignFilters.live_now(now)
    |> Repo.all()
  end

  defp activate_within_budget(me_file_ids, budgets, now) do
    limits = Enum.map(me_file_ids, fn id -> {id, budgets[id].remaining} end)
    offers = due_offers_within_budget(limits, now)

    offers
    |> Enum.group_by(& &1.me_file_id)
    |> Enum.reduce(0, fn {_me_file_id, rows}, acc ->
      ids = Enum.map(rows, & &1.id)

      {activated, _} =
        from(o in Offer, where: o.id in ^ids)
        |> Repo.update_all(set: [is_current: true, updated_at: now])

      if activated > 0 do
        rows
        |> Enum.map(& &1.campaign_id)
        |> Enum.uniq()
        |> Enum.each(&CampaignPubSub.broadcast_offers_created(&1, activated))
      end

      acc + activated
    end)
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

    %{rows: rows} = Repo.query!(sql, [ids, remainings, now])

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
