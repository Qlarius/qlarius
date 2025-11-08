defmodule Qlarius.Sponster.Campaigns.Bid do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Campaigns.{Campaign, MediaRun, TargetBand}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "bids" do
    field :offer_amt, :decimal
    field :marketer_cost_amt, :decimal

    belongs_to :campaign, Campaign
    belongs_to :media_run, MediaRun
    belongs_to :target_band, TargetBand

    timestamps()
  end

  def changeset(bid, attrs) do
    bid
    |> cast(attrs, [:campaign_id, :media_run_id, :target_band_id, :offer_amt, :marketer_cost_amt])
    |> validate_required([
      :campaign_id,
      :media_run_id,
      :target_band_id,
      :offer_amt,
      :marketer_cost_amt
    ])
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:media_run_id)
    |> foreign_key_constraint(:target_band_id)
  end
end
