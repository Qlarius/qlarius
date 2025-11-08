defmodule Qlarius.Sponster.Campaigns do
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Sponster.Campaigns.{Campaign, Bid, Target, MediaSequence}
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
  Deactivates a campaign by setting deactivated_at.
  """
  def deactivate_campaign(campaign) do
    campaign
    |> Ecto.Changeset.change(%{
      deactivated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.update()
  end

  @doc """
  Reactivates a campaign by setting deactivated_at to nil.
  """
  def reactivate_campaign(campaign) do
    campaign
    |> Ecto.Changeset.change(%{deactivated_at: nil})
    |> Repo.update()
  end
end
