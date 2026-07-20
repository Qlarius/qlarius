defmodule Qlarius.Sponster.Offers do
  @moduledoc """
  The Offers context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Qlarius.Repo
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Sponster.Ads.MediaPiecePhase
  alias Qlarius.Sponster.Offer
  alias Qlarius.Sponster.OfferCompletion
  alias Qlarius.Sponster.Campaigns.CampaignPubSub
  alias Qlarius.System
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  @completion_kind_full_funnel "full_funnel"
  @completion_kind_banner_max "banner_max"

  @doc """
  Returns the list of offers for a user, in descending order of their amount
  """

  # def list_user_offers(user_id) do
  #   from(o in Offer,
  #     join: u in assoc(o, :user),
  #     where: u.id == ^user_id and o.is_current == true,
  #     order_by: [desc: o.amount],
  #     preload: [:ad_category, :media_piece]
  #   )
  #   |> Repo.all()
  # end

  # def count_user_offers(user_id) do
  #   from(o in Offer, join: u in assoc(o, :user), where: u.id == ^user_id)
  #   |> Repo.count()
  # end

  def total_active_offer_amount(me_file) do
    from(o in Offer, where: o.me_file_id == ^me_file.id and o.is_current == true)
    |> Repo.aggregate(:sum, :offer_amt)
  end

  def get_offer_with_media_piece!(id) do
    Repo.get!(Offer, id) |> Repo.preload(:media_piece)
  end

  def get_offer_with_media_piece(id) do
    case Repo.get(Offer, id) do
      nil -> nil
      offer -> Repo.preload(offer, :media_piece)
    end
  end

  @doc """
  Creates a pending copy of an offer with a future pending_until timestamp and deletes the original.
  Returns {:ok, new_offer} if successful, {:error, changeset} if creation fails.

  This function is to be updated to check the media_run parameters and create a new offer only if needed. For now, it just creates a new offer with a future pending_until timestamp and deletes the original for demo purposes.
  """
  def create_pending_copy_and_delete_original(offer, hours) do
    pending_until = DateTime.add(DateTime.utc_now(), hours, :hour)

    offer_copy =
      %{offer | id: nil, is_current: false, pending_until: pending_until}
      |> Map.from_struct()
      |> Map.drop([:created_at, :updated_at])

    Multi.new()
    |> Multi.delete(:delete_original, offer)
    |> Multi.insert(:new_offer, Offer.changeset(%Offer{}, offer_copy))
    |> Repo.transaction()
    |> case do
      {:ok, %{new_offer: new_offer}} -> {:ok, new_offer}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Synchronously refreshes offer statuses for a me_file and notifies subscribers.

  For current 3-tap offers:

  * If a complete AdEvent already exists (e.g. jump just finished) → finalize
    immediately so the offer is never left `is_current`.
  * If `maximum_banner_count` paid banner collects are reached without a jump →
    write a `completion_kind: "banner_max"` complete event (counts toward
    media_run frequency, excluded from engagement reporting) and finalize.
  * Else if still inside `banner_retry_buffer_hours` since the latest banner
    collect → park (`is_current: false`, `pending_until = last_banner + buffer`).

  Then activates pending offers whose `pending_until` has elapsed.

  Listing always restarts at UI phase 0 (banner reveal).
  """
  def refresh_statuses_for_me_file(me_file_id) when is_integer(me_file_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Finalize completes / banner-max and park in-buffer banners first so throttle
    # slots free up, then activate due pendings, then park-only newly activated
    # offers (never finalize twice in one refresh).
    {parked_before, finalized} = apply_three_tap_media_run_rules(me_file_id, now, :full)
    activated = activate_pending_for_me_file(me_file_id, now)
    {parked_after, _} = apply_three_tap_media_run_rules(me_file_id, now, :park_only)

    parked = parked_before + parked_after

    MeFileStatsBroadcaster.broadcast_stats_updated(me_file_id)
    MeFileStatsBroadcaster.broadcast_offers_updated(me_file_id)

    if activated > 0 do
      CampaignPubSub.broadcast_offers_activated()
    end

    {:ok, %{activated: activated, parked: parked, finalized: finalized}}
  end

  @doc """
  Current 3-tap offers for listing. Always returns UI phase `0` — the funnel
  starts at the banner; in-session progress is owned by `ThreeTapStackComponent`.
  """
  def list_current_three_tap_offers(me_file_id) when is_integer(me_file_id) do
    from(o in Offer,
      join: mp in assoc(o, :media_piece),
      where: o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 1,
      order_by: [desc: o.offer_amt],
      preload: [media_piece: :ad_category]
    )
    |> Repo.all()
    |> Enum.map(fn offer -> {offer, 0} end)
  end

  def completion_kind_full_funnel, do: @completion_kind_full_funnel
  def completion_kind_banner_max, do: @completion_kind_banner_max

  defp apply_three_tap_media_run_rules(me_file_id, now, mode)
       when mode in [:full, :park_only] do
    phase_1_id = three_tap_phase_1_id()

    current_three_tap_offers(me_file_id)
    |> Enum.reduce({0, 0}, fn offer, {parked, finalized} ->
      case apply_offer_status_rules(offer, phase_1_id, now, mode) do
        :finalized -> {parked, finalized + 1}
        :parked -> {parked + 1, finalized}
        :unchanged -> {parked, finalized}
      end
    end)
  end

  defp current_three_tap_offers(me_file_id) do
    from(o in Offer,
      join: mp in assoc(o, :media_piece),
      where: o.me_file_id == ^me_file_id and o.is_current == true and mp.media_piece_type_id == 1,
      preload: [:media_run]
    )
    |> Repo.all()
  end

  defp apply_offer_status_rules(offer, phase_1_id, now, :full) do
    case latest_complete_event_at(offer.id) do
      %NaiveDateTime{} = completed_at ->
        case OfferCompletion.finalize(offer.id, completed_at) do
          {:ok, :already_finalized} -> :unchanged
          {:ok, _} -> :finalized
          {:error, _} -> :unchanged
        end

      nil ->
        apply_banner_rules(offer, phase_1_id, now, :full)
    end
  end

  defp apply_offer_status_rules(offer, phase_1_id, now, :park_only) do
    apply_banner_rules(offer, phase_1_id, now, :park_only)
  end

  defp apply_banner_rules(offer, phase_1_id, now, mode) do
    media_run = offer.media_run

    if is_nil(media_run) or is_nil(phase_1_id) do
      :unchanged
    else
      {phase1_count, last_phase1_at} = phase1_collect_stats(offer.id, phase_1_id)
      max_banners = media_run.maximum_banner_count
      retry_hours = media_run.banner_retry_buffer_hours

      cond do
        phase1_count == 0 ->
          :unchanged

        mode == :full and is_integer(max_banners) and phase1_count >= max_banners ->
          insert_banner_max_completion!(offer, phase_1_id, last_phase1_at || now)

          case OfferCompletion.finalize(offer.id, last_phase1_at || now) do
            {:ok, :already_finalized} -> :unchanged
            {:ok, _} -> :finalized
            {:error, _} -> :unchanged
          end

        is_integer(retry_hours) and retry_hours > 0 and not is_nil(last_phase1_at) ->
          pending_until =
            last_phase1_at
            |> NaiveDateTime.add(retry_hours * 3600, :second)
            |> NaiveDateTime.truncate(:second)

          if NaiveDateTime.compare(pending_until, now) == :gt do
            park_offer(offer.id, pending_until, now)
            :parked
          else
            :unchanged
          end

        true ->
          :unchanged
      end
    end
  end

  defp insert_banner_max_completion!(offer, phase_1_id, at) do
    at = NaiveDateTime.truncate(at, :second)

    %AdEvent{}
    |> AdEvent.changeset(%{
      offer_bid_amt: offer.offer_amt,
      is_throttled: offer.is_throttled,
      is_demo: offer.is_demo,
      is_offer_complete: true,
      completion_kind: @completion_kind_banner_max,
      ip_address: "0.0.0.0",
      url: "sponster://banner_max",
      offer_id: offer.id,
      me_file_id: offer.me_file_id,
      campaign_id: offer.campaign_id,
      media_run_id: offer.media_run_id,
      media_piece_id: offer.media_piece_id,
      media_piece_phase_id: phase_1_id,
      target_band_id: offer.target_band_id,
      is_payable: false,
      offer_marketer_cost_amt: Decimal.new("0"),
      event_marketer_cost_amt: Decimal.new("0"),
      event_me_file_collect_amt: Decimal.new("0"),
      event_sponster_collect_amt: Decimal.new("0"),
      matching_tags_snapshot: offer.matching_tags_snapshot || %{}
    })
    |> Ecto.Changeset.put_change(:created_at, at)
    |> Ecto.Changeset.put_change(:updated_at, at)
    |> Repo.insert!()
  end

  defp park_offer(offer_id, pending_until, now) do
    from(o in Offer, where: o.id == ^offer_id)
    |> Repo.update_all(
      set: [is_current: false, pending_until: pending_until, updated_at: now]
    )
  end

  defp latest_complete_event_at(offer_id) do
    from(ae in AdEvent,
      where: ae.offer_id == ^offer_id and ae.is_offer_complete == true,
      order_by: [desc: ae.created_at],
      select: ae.created_at,
      limit: 1
    )
    |> Repo.one()
  end

  defp three_tap_phase_1_id do
    from(mpp in MediaPiecePhase,
      where: mpp.media_piece_type_id == 1,
      where: mpp.phase == 1,
      select: mpp.id,
      limit: 1
    )
    |> Repo.one()
  end

  defp phase1_collect_stats(offer_id, phase_1_id) do
    rows =
      from(ae in AdEvent,
        where: ae.offer_id == ^offer_id,
        where: ae.media_piece_phase_id == ^phase_1_id,
        where: ae.is_offer_complete == false,
        order_by: [desc: ae.created_at],
        select: ae.created_at
      )
      |> Repo.all()

    {length(rows), List.first(rows)}
  end

  defp activate_pending_for_me_file(me_file_id, now) do
    throttle_limit = System.get_global_variable_int("THROTTLE_AD_COUNT", 3)
    throttle_days = System.get_global_variable_int("THROTTLE_DAYS", 7)

    unthrottled = activate_unthrottled_for_me_file(me_file_id, now)
    throttled = activate_throttled_for_me_file(me_file_id, now, throttle_limit, throttle_days)
    unthrottled + throttled
  end

  defp activate_unthrottled_for_me_file(me_file_id, now) do
    {count, _} =
      from(o in Offer,
        where: o.me_file_id == ^me_file_id,
        where: o.is_current == false,
        where: o.is_throttled == false,
        where: o.pending_until <= ^now
      )
      |> Repo.update_all(set: [is_current: true, updated_at: now])

    count
  end

  defp activate_throttled_for_me_file(me_file_id, now, throttle_limit, throttle_days) do
    since = NaiveDateTime.add(now, -throttle_days * 24 * 60 * 60, :second)

    pending =
      from(o in Offer,
        where: o.me_file_id == ^me_file_id,
        where: o.is_current == false,
        where: o.is_throttled == true,
        where: o.pending_until <= ^now,
        order_by: [asc: o.pending_until, asc: o.id],
        select: o.id
      )
      |> Repo.all()

    current_count = count_current_throttled_offers(me_file_id)
    completed_count = count_completed_throttled_ads(me_file_id, since)
    remaining_slots = max(0, throttle_limit - max(current_count, completed_count))

    offer_ids = Enum.take(pending, remaining_slots)

    if offer_ids == [] do
      0
    else
      {count, _} =
        from(o in Offer, where: o.id in ^offer_ids)
        |> Repo.update_all(set: [is_current: true, updated_at: now])

      count
    end
  end

  defp count_current_throttled_offers(me_file_id) do
    from(o in Offer,
      where: o.me_file_id == ^me_file_id,
      where: o.is_current == true,
      where: o.is_throttled == true,
      select: count(o.id)
    )
    |> Repo.one()
  end

  defp count_completed_throttled_ads(me_file_id, since_date) do
    from(ae in AdEvent,
      where: ae.me_file_id == ^me_file_id,
      where: ae.is_throttled == true,
      where: ae.created_at >= ^since_date,
      select: count(ae.id)
    )
    |> Repo.one()
  end
end
