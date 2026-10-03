defmodule Qlarius.AdminApi.Campaigns do
  @moduledoc """
  Campaign reads and writes for the admin API.

  Creating a PTP campaign (`is_ptp: true`) defaults it to non-payable and
  throttled unless those fields are sent. Launching requires `confirm: true`.
  """

  import Ecto.Query, except: [update: 2, update: 3]

  alias Qlarius.{ApiRef, Repo}
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Sponster.Ads.MediaPiece
  alias Qlarius.Sponster.Campaigns
  alias Qlarius.Sponster.Campaigns.{Bid, Campaign, MediaRun, MediaSequence, Target, Targets}
  alias Qlarius.Wallets.{LedgerEntry, LedgerHeader}

  def list(params) do
    from(c in Campaign, order_by: [desc: c.id], preload: [:bids, :target])
    |> filter_marketer(params["marketer_id"])
    |> filter_ptp(params["is_ptp"])
    |> filter_status(params["status"])
    |> filter_prefix(params["api_ref_prefix"])
    |> limit(100)
    |> Repo.all()
  end

  def fetch(id) do
    case Repo.get(Campaign, id) do
      nil -> {:error, :not_found}
      campaign -> {:ok, detail(campaign)}
    end
  end

  def create(params, opts) do
    with {:ok, target, _sequence, piece} <- linked(params),
         bids <- bids_for(target, piece) do
      existing = if params["api_ref"], do: Repo.get_by(Campaign, api_ref: params["api_ref"])

      cond do
        params["api_ref"] in [nil, ""] ->
          {:error, :api_ref_required}

        not ApiRef.valid?(params["api_ref"]) ->
          {:error, :invalid_api_ref}

        existing && existing.marketer_id != target.marketer_id ->
          {:error, {:api_ref_conflict, params["api_ref"]}}

        existing && params["on_existing"] != "update" ->
          {:ok, %{result: "matched", matched: true, record: detail(existing), bids: bids}}

        opts[:dry_run] ->
          {:ok,
           %{
             result: if(existing, do: "would_update", else: "would_create"),
             bids: bids,
             record: existing && detail(existing)
           }}

        existing ->
          update(existing, params, opts)

        true ->
          case Campaigns.create_campaign_with_ledger_and_bids(target.marketer_id, params) do
            {:ok, campaign} -> {:ok, %{result: "created", record: detail(campaign), bids: bids}}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  def update(campaign, params, opts) do
    launched = not is_nil(campaign.launched_at)

    cond do
      launched && (Map.has_key?(params, "target_id") or Map.has_key?(params, "media_sequence_id")) ->
        {:error, :launched_structure_locked}

      Map.has_key?(params, "api_ref") && params["api_ref"] != campaign.api_ref ->
        {:error, :api_ref_immutable}

      opts[:dry_run] ->
        {:ok,
         %{
           result: "would_update",
           would_refresh_offers: launched && flag_change?(params),
           record: detail(campaign)
         }}

      true ->
        case campaign |> Campaign.changeset(params) |> Repo.update() do
          {:ok, campaign} ->
            if launched && flag_change?(params), do: Campaigns.refresh_campaign_offers(campaign)
            {:ok, %{result: "updated", record: detail(campaign)}}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def bid_preview(params) do
    with {:ok, target, _sequence, piece} <- linked(params) do
      bids = bids_for(target, piece)
      total = Enum.reduce(bids, Decimal.new(0), &Decimal.add(&2, &1.worst_case))

      {:ok, %{bids: bids, worst_case_total: total}}
    end
  end

  def launch(campaign, params) do
    cond do
      params["confirm"] not in [true, "true"] ->
        {:error, :confirm_required}

      true ->
        campaign =
          Repo.preload(campaign, [
            :bids,
            target: :target_bands,
            media_sequence: [media_runs: [media_piece: :ad_category]]
          ])

        case preflight(campaign) do
          :ok -> Campaigns.launch_campaign(campaign)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def deactivate(campaign, opts) do
    count = Repo.aggregate(from(o in Offer, where: o.campaign_id == ^campaign.id), :count)

    if opts[:dry_run] do
      {:ok, %{result: "would_deactivate", offers_deleted: count}}
    else
      with {:ok, campaign} <- Campaigns.deactivate_campaign(campaign) do
        {:ok, %{result: "deactivated", record: detail(campaign), offers_deleted: count}}
      end
    end
  end

  def reactivate(campaign) do
    with {:ok, campaign} <- Campaigns.reactivate_campaign(campaign) do
      {:ok, %{result: "reactivated", record: detail(campaign)}}
    end
  end

  def offers(campaign, params) do
    limit =
      params["limit"]
      |> to_string()
      |> Integer.parse()
      |> case do
        {n, ""} when n > 0 -> min(n, 50)
        _ -> 20
      end

    sample =
      from(o in Offer,
        where: o.campaign_id == ^campaign.id,
        limit: ^limit,
        order_by: [desc: o.id]
      )
      |> Repo.all()
      |> Enum.map(
        &Map.take(&1, [:id, :me_file_id, :offer_amt, :is_current, :is_throttled, :is_payable])
      )

    %{
      total: Repo.aggregate(from(o in Offer, where: o.campaign_id == ^campaign.id), :count),
      current:
        Repo.aggregate(
          from(o in Offer, where: o.campaign_id == ^campaign.id and o.is_current == true),
          :count
        ),
      sample: sample
    }
  end

  def delete(campaign, opts) do
    entries =
      Repo.aggregate(
        from(e in LedgerEntry,
          join: h in assoc(e, :ledger_header),
          where: h.campaign_id == ^campaign.id
        ),
        :count
      )

    cond do
      not is_nil(campaign.launched_at) ->
        {:error, :launched}

      entries > 0 ->
        {:error, {:has_dependents, %{ledger_entries: entries}}}

      opts[:dry_run] ->
        {:ok,
         %{result: "would_delete", removes: %{campaign: campaign.id, bids: true, ledger: true}}}

      true ->
        Repo.delete_all(from(b in Bid, where: b.campaign_id == ^campaign.id))
        Repo.delete_all(from(h in LedgerHeader, where: h.campaign_id == ^campaign.id))
        Repo.delete!(campaign)
        {:ok, %{result: "deleted", removes: %{campaign: campaign.id}}}
    end
  end

  defp linked(params) do
    target = Repo.get(Target, int(params["target_id"])) |> Repo.preload(:target_bands)
    sequence = Repo.get(MediaSequence, int(params["media_sequence_id"]))

    piece =
      if sequence do
        Repo.one(
          from(p in MediaPiece,
            join: r in MediaRun,
            on: r.media_piece_id == p.id,
            where: r.media_sequence_id == ^sequence.id,
            limit: 1,
            preload: [:media_piece_type, :ad_category]
          )
        )
      end

    cond do
      is_nil(target) or is_nil(sequence) ->
        {:error, :not_found}

      target.marketer_id != sequence.marketer_id ->
        {:error, :target_sequence_mismatch}

      target.marketer_id != int(params["marketer_id"]) ->
        {:error, :wrong_marketer}

      not is_nil(target.archived_at) ->
        {:error, :target_archived}

      is_nil(piece) ->
        {:error, :sequence_has_no_run}

      true ->
        {:ok, target, sequence, piece}
    end
  end

  defp bids_for(target, piece) do
    counts = Targets.get_band_population_counts(target.id)

    piece.media_piece_type
    |> Campaigns.compute_bids(target.target_bands)
    |> Enum.map(fn bid ->
      population = Map.get(counts, bid.target_band_id, 0)

      Map.merge(bid, %{
        population: population,
        worst_case: Decimal.mult(bid.marketer_cost_amt, population)
      })
    end)
  end

  defp preflight(campaign) do
    run = List.first(campaign.media_sequence.media_runs || [])
    piece = run && run.media_piece
    band_ids = Enum.map(campaign.target.target_bands, & &1.id)
    bid_ids = Enum.map(campaign.bids, & &1.target_band_id)

    cond do
      campaign.target.target_bands == [] -> {:error, :target_has_no_bands}
      is_nil(run) -> {:error, :sequence_has_no_run}
      piece && piece.active != true -> {:error, :media_piece_inactive}
      piece && piece.ad_category && piece.ad_category.active != true -> {:error, :row_inactive}
      Enum.any?(band_ids, &(&1 not in bid_ids)) -> {:error, :missing_bids}
      true -> :ok
    end
  end

  defp detail(campaign) do
    campaign =
      Repo.preload(
        campaign,
        [:bids, :target, :ledger_header, media_sequence: [media_runs: :media_piece]],
        force: true
      )

    balance = campaign.ledger_header && campaign.ledger_header.balance

    %{
      id: campaign.id,
      api_ref: campaign.api_ref,
      title: campaign.title,
      description: campaign.description,
      marketer_id: campaign.marketer_id,
      target_id: campaign.target_id,
      media_sequence_id: campaign.media_sequence_id,
      is_ptp: campaign.is_ptp,
      is_payable: campaign.is_payable,
      is_throttled: campaign.is_throttled,
      is_demo: campaign.is_demo,
      status: status(campaign),
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      launched_at: campaign.launched_at,
      deactivated_at: campaign.deactivated_at,
      population_status: campaign.target && campaign.target.population_status,
      ledger_balance: balance,
      ad_events: Repo.aggregate(from(e in AdEvent, where: e.campaign_id == ^campaign.id), :count),
      offers: Repo.aggregate(from(o in Offer, where: o.campaign_id == ^campaign.id), :count),
      bids:
        Enum.map(
          campaign.bids,
          &Map.take(&1, [:id, :target_band_id, :offer_amt, :marketer_cost_amt])
        )
    }
  end

  defp status(%{deactivated_at: at}) when not is_nil(at), do: "deactivated"
  defp status(%{launched_at: at}) when not is_nil(at), do: "launched"
  defp status(_), do: "draft"

  defp flag_change?(params) do
    Enum.any?(~w(is_payable is_throttled is_demo is_ptp), &Map.has_key?(params, &1))
  end

  defp filter_marketer(query, id) when id not in [nil, ""],
    do: where(query, [c], c.marketer_id == ^int(id))

  defp filter_marketer(query, _), do: query

  defp filter_ptp(query, value) when value in [true, false, "true", "false"] do
    where(query, [c], c.is_ptp == ^(value in [true, "true"]))
  end

  defp filter_ptp(query, _), do: query

  defp filter_status(query, "draft"),
    do: where(query, [c], is_nil(c.launched_at) and is_nil(c.deactivated_at))

  defp filter_status(query, "launched"),
    do: where(query, [c], not is_nil(c.launched_at) and is_nil(c.deactivated_at))

  defp filter_status(query, "deactivated"), do: where(query, [c], not is_nil(c.deactivated_at))
  defp filter_status(query, _), do: query

  defp filter_prefix(query, prefix) when is_binary(prefix) and prefix != "" do
    where(query, [c], like(c.api_ref, ^"#{prefix}%"))
  end

  defp filter_prefix(query, _), do: query

  defp int(id) when is_integer(id), do: id

  defp int(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp int(_), do: nil
end
