defmodule Qlarius.Sponster.Campaigns do
  import Ecto.Query
  alias Ecto.Multi
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, Bid, Target, MediaSequence, Targets}
  alias Qlarius.Sponster.Offer
  alias Qlarius.Wallets

  @doc """
  Lists all campaigns for a marketer, ordered by most recently created.
  Preloads target, media_sequence with media_runs, and bids.
  """
  def list_campaigns_for_marketer(marketer_id) do
    from(c in Campaign,
      where: c.marketer_id == ^marketer_id and is_nil(c.deactivated_at),
      order_by: [desc: c.created_at],
      preload: [
        target: [target_bands: [:trait_groups]],
        media_sequence: [media_runs: [media_piece: :media_piece_type]],
        bids: [],
        ledger_header: []
      ]
    )
    |> Repo.all()
  end

  @doc """
  Lists all archived campaigns for a marketer.
  """
  def list_archived_campaigns_for_marketer(marketer_id) do
    from(c in Campaign,
      where: c.marketer_id == ^marketer_id and not is_nil(c.deactivated_at),
      order_by: [desc: c.deactivated_at],
      preload: [
        target: [target_bands: [:trait_groups]],
        media_sequence: [media_runs: [media_piece: :media_piece_type]],
        bids: [],
        ledger_header: []
      ]
    )
    |> Repo.all()
  end

  @doc """
  Gets a campaign for a marketer with preloaded associations.
  """
  def get_campaign_for_marketer!(id, marketer_id) do
    Repo.get_by!(Campaign, id: id, marketer_id: marketer_id)
    |> Repo.preload(
      target: [target_bands: [:trait_groups]],
      media_sequence: [media_runs: [media_piece: :media_piece_type]],
      bids: [],
      ledger_header: []
    )
  end

  @doc """
  Creates a campaign with its associated ledger and bids for each target band.

  Steps:
  1. Create the campaign
  2. Create campaign ledger
  3. Calculate and create bids for each target band:
     - Sort bands by ID (smallest = bullseye, largest = outermost)
     - Outermost band gets $0.10 offer_amt
     - Each inner band adds $0.01
     - Calculate marketer_cost_amt = (offer_amt × 1.5) + $0.10, rounded to 2 decimals
  """
  def create_campaign_with_ledger_and_bids(marketer_id, attrs) do
    Repo.transaction(fn ->
      campaign_attrs =
        attrs
        |> Map.put("marketer_id", marketer_id)
        |> Map.put(
          "start_date",
          attrs["start_date"] || NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        )

      campaign =
        %Campaign{}
        |> Campaign.changeset(campaign_attrs)
        |> Repo.insert!()

      Wallets.create_campaign_ledger_header(campaign, marketer_id)

      target = Repo.get!(Target, attrs["target_id"]) |> Repo.preload(:target_bands)

      bands = Enum.sort_by(target.target_bands, & &1.id)

      media_sequence =
        Repo.get!(MediaSequence, attrs["media_sequence_id"]) |> Repo.preload(:media_runs)

      media_run = List.first(media_sequence.media_runs)

      unless media_run do
        Repo.rollback("Media sequence has no media runs")
      end

      band_count = length(bands)

      bands
      |> Enum.with_index()
      |> Enum.each(fn {band, index} ->
        offer_amt =
          Decimal.new("0.10")
          |> Decimal.add(Decimal.new("0.01") |> Decimal.mult(band_count - index - 1))

        marketer_cost_amt =
          offer_amt
          |> Decimal.mult(Decimal.new("1.5"))
          |> Decimal.add(Decimal.new("0.10"))
          |> Decimal.round(2)

        %Bid{}
        |> Bid.changeset(%{
          campaign_id: campaign.id,
          media_run_id: media_run.id,
          target_band_id: band.id,
          offer_amt: offer_amt,
          marketer_cost_amt: marketer_cost_amt
        })
        |> Repo.insert!()
      end)

      campaign
    end)
  end

  @doc """
  Deactivates a campaign by setting deactivated_at and deleting all associated offers.
  """
  def deactivate_campaign(campaign) do
    Multi.new()
    |> Multi.delete_all(:delete_offers, from(o in Offer, where: o.campaign_id == ^campaign.id))
    |> Multi.update(
      :deactivate_campaign,
      Ecto.Changeset.change(campaign, %{
        deactivated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{deactivate_campaign: updated_campaign}} -> {:ok, updated_campaign}
      {:error, _failed_operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Reactivates a campaign by setting deactivated_at to nil.
  """
  def reactivate_campaign(campaign) do
    campaign
    |> Ecto.Changeset.change(%{deactivated_at: nil})
    |> Repo.update()
  end

  @doc """
  Launches a campaign by:
  1. Deleting any existing offers for the campaign (to clear legacy data)
  2. Triggering target population if not already populated
  3. Setting launched_at to current timestamp
  4. Enqueuing an OBAN worker to create pending offers
  """
  def launch_campaign(campaign) do
    alias Qlarius.Sponster.Offer

    campaign = Repo.preload(campaign, :target)

    if campaign.target.population_status == "not_populated" do
      Targets.trigger_population(campaign.target)
    end

    with {:ok, updated_campaign} <-
           Repo.transaction(fn ->
             from(o in Offer, where: o.campaign_id == ^campaign.id)
             |> Repo.delete_all()

             case campaign
                  |> Ecto.Changeset.change(%{
                    launched_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
                  })
                  |> Repo.update() do
               {:ok, updated_campaign} -> updated_campaign
               {:error, changeset} -> Repo.rollback(changeset)
             end
           end),
         {:ok, _job} <-
           %{"campaign_id" => updated_campaign.id}
           |> Qlarius.Jobs.CreateInitialPendingOffersWorker.new()
           |> Oban.insert() do
      {:ok, updated_campaign}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Refreshes offers for a launched campaign by:
  1. Triggering target population if not already populated
  2. Deleting all existing offers for the campaign
  3. Re-enqueuing the OBAN worker to create fresh offers based on current target populations and bids
  """
  def refresh_campaign_offers(campaign) do
    alias Qlarius.Sponster.Offer

    campaign = Repo.preload(campaign, :target)

    if campaign.target.population_status == "not_populated" do
      Targets.trigger_population(campaign.target)
    end

    with {:ok, _} <-
           Repo.transaction(fn ->
             from(o in Offer, where: o.campaign_id == ^campaign.id)
             |> Repo.delete_all()
           end),
         {:ok, _job} <-
           %{"campaign_id" => campaign.id}
           |> Qlarius.Jobs.CreateInitialPendingOffersWorker.new()
           |> Oban.insert() do
      {:ok, campaign}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates missing bids and validates the entire bid set for a campaign.
  Ensures all bids meet requirements:
  - Minimum bid of $0.10
  - Bids increase by at least $0.01 from outer to inner bands
  Adjusts existing bids only when necessary to meet requirements.
  """
  def create_missing_bids(campaign) do
    bands = Enum.sort_by(campaign.target.target_bands, & &1.id)
    existing_bids = Enum.group_by(campaign.bids, & &1.target_band_id)

    media_run =
      if campaign.media_sequence.media_runs == [] do
        nil
      else
        List.first(campaign.media_sequence.media_runs)
      end

    if is_nil(media_run) do
      {:error, "No media run available"}
    else
      create_bids_for_missing_bands(campaign, bands, existing_bids, media_run)
    end
  end

  defp create_bids_for_missing_bands(campaign, bands, existing_bids, media_run) do
    missing_bands =
      Enum.filter(bands, fn band ->
        !Map.has_key?(existing_bids, band.id)
      end)

    if length(missing_bands) > 0 || needs_bid_validation?(bands, existing_bids) do
      Repo.transaction(fn ->
        calculated_bids = calculate_valid_bid_set(bands, existing_bids)

        Enum.each(bands, fn band ->
          new_offer_amt = Map.get(calculated_bids, band.id)

          existing_bid =
            case Map.get(existing_bids, band.id) do
              [bid | _] -> bid
              _ -> nil
            end

          marketer_cost_amt =
            new_offer_amt
            |> Decimal.mult(Decimal.new("1.5"))
            |> Decimal.add(Decimal.new("0.10"))
            |> Decimal.round(2)

          if existing_bid do
            unless Decimal.eq?(existing_bid.offer_amt, new_offer_amt) do
              existing_bid
              |> Bid.changeset(%{
                offer_amt: new_offer_amt,
                marketer_cost_amt: marketer_cost_amt
              })
              |> Repo.update!()
            end
          else
            %Bid{}
            |> Bid.changeset(%{
              campaign_id: campaign.id,
              media_run_id: media_run.id,
              target_band_id: band.id,
              offer_amt: new_offer_amt,
              marketer_cost_amt: marketer_cost_amt
            })
            |> Repo.insert!()
          end
        end)

        :ok
      end)
    else
      {:ok, :no_action_needed}
    end
  end

  defp needs_bid_validation?(bands, existing_bids) do
    bands
    |> Enum.with_index()
    |> Enum.any?(fn {band, index} ->
      case Map.get(existing_bids, band.id) do
        [bid | _] ->
          cond do
            Decimal.lt?(bid.offer_amt, Decimal.new("0.10")) ->
              true

            index < length(bands) - 1 ->
              outer_band = Enum.at(bands, index + 1)

              case Map.get(existing_bids, outer_band.id) do
                [outer_bid | _] ->
                  Decimal.lte?(bid.offer_amt, outer_bid.offer_amt)

                _ ->
                  false
              end

            true ->
              false
          end

        _ ->
          false
      end
    end)
  end

  defp calculate_valid_bid_set(bands, existing_bids) do
    bands
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn band, acc ->
      existing_bid_amt =
        case Map.get(existing_bids, band.id) do
          [bid | _] -> bid.offer_amt
          _ -> nil
        end

      band_index = Enum.find_index(bands, fn b -> b.id == band.id end)

      outer_band_amt =
        if band_index < length(bands) - 1 do
          outer_band = Enum.at(bands, band_index + 1)
          Map.get(acc, outer_band.id)
        else
          nil
        end

      minimum_allowed =
        if outer_band_amt do
          Decimal.add(outer_band_amt, Decimal.new("0.01"))
        else
          Decimal.new("0.10")
        end

      calculated_amt =
        cond do
          existing_bid_amt && Decimal.gte?(existing_bid_amt, minimum_allowed) ->
            existing_bid_amt

          true ->
            minimum_allowed
        end

      Map.put(acc, band.id, calculated_amt)
    end)
  end

  @doc """
  Fixes all campaigns by ensuring all target bands have corresponding bids.
  Useful for fixing legacy data issues.

  ## Examples in IEx

      # Fix a single campaign
      Qlarius.Sponster.Campaigns.ensure_all_bands_have_bids(campaign_id)

      # Fix all campaigns
      Qlarius.Sponster.Campaigns.ensure_all_campaigns_have_bids()
  """
  def ensure_all_bands_have_bids(campaign_id) do
    campaign =
      Repo.get!(Campaign, campaign_id)
      |> Repo.preload(
        target: [target_bands: [:trait_groups]],
        media_sequence: [media_runs: [media_piece: :media_piece_type]],
        bids: [],
        ledger_header: []
      )

    target_band_ids = Enum.map(campaign.target.target_bands, & &1.id) |> MapSet.new()
    bid_band_ids = Enum.map(campaign.bids, & &1.target_band_id) |> MapSet.new()

    missing_bands = MapSet.difference(target_band_ids, bid_band_ids)

    if MapSet.size(missing_bands) > 0 do
      Repo.transaction(fn ->
        from(b in Bid, where: b.campaign_id == ^campaign.id)
        |> Repo.delete_all()

        bands = Enum.sort_by(campaign.target.target_bands, & &1.id)
        band_count = length(bands)
        media_run = List.first(campaign.media_sequence.media_runs)

        unless media_run do
          Repo.rollback("Media sequence has no media runs")
        end

        bands
        |> Enum.with_index()
        |> Enum.each(fn {band, index} ->
          offer_amt =
            Decimal.new("0.10")
            |> Decimal.add(Decimal.new("0.01") |> Decimal.mult(band_count - index - 1))

          marketer_cost_amt =
            offer_amt
            |> Decimal.mult(Decimal.new("1.5"))
            |> Decimal.add(Decimal.new("0.10"))
            |> Decimal.round(2)

          %Bid{}
          |> Bid.changeset(%{
            campaign_id: campaign.id,
            media_run_id: media_run.id,
            target_band_id: band.id,
            offer_amt: offer_amt,
            marketer_cost_amt: marketer_cost_amt
          })
          |> Repo.insert!()
        end)

        :ok
      end)
    else
      {:ok, :no_action_needed}
    end
  end

  @doc """
  Ensures ALL campaigns have bids for all their target bands.
  Returns a summary of actions taken.
  """
  def ensure_all_campaigns_have_bids do
    campaigns = Repo.all(Campaign)

    results =
      Enum.map(campaigns, fn campaign ->
        case ensure_all_bands_have_bids(campaign.id) do
          {:ok, :no_action_needed} ->
            {:ok, campaign.id, :no_action}

          {:ok, _} ->
            {:ok, campaign.id, :fixed}

          {:error, reason} ->
            {:error, campaign.id, reason}
        end
      end)

    fixed_count =
      Enum.count(results, fn {status, _, action} -> status == :ok && action == :fixed end)

    ok_count =
      Enum.count(results, fn {status, _, action} -> status == :ok && action == :no_action end)

    error_count = Enum.count(results, fn {status, _, _} -> status == :error end)

    IO.puts("\nCampaign Bid Fix Summary:")
    IO.puts("  Fixed: #{fixed_count}")
    IO.puts("  Already OK: #{ok_count}")
    IO.puts("  Errors: #{error_count}")

    if error_count > 0 do
      IO.puts("\nErrors:")

      Enum.each(results, fn
        {:error, id, reason} -> IO.puts("  Campaign #{id}: #{inspect(reason)}")
        _ -> :ok
      end)
    end

    {:ok, %{fixed: fixed_count, ok: ok_count, errors: error_count}}
  end
end
