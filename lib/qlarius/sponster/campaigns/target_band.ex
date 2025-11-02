defmodule Qlarius.Sponster.Campaigns.TargetBand do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.TargetBandTraitGroup

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "target_bands" do
    # Target association commented - schema only in archive_hide
    # belongs_to :target, Target

    has_many :target_band_trait_groups, TargetBandTraitGroup
    has_many :trait_groups, through: [:target_band_trait_groups, :trait_group]

    # TargetPopulation association commented - schema does not exist
    # has_many :target_populations, Qlarius.Sponster.Campaigns.TargetPopulation
    # has_many :me_files, through: [:target_populations, :me_file]
    # Bid association commented - schema does not exist
    # has_many :bids, Bid
    has_many :offers, Offer
    has_many :ad_events, AdEvent

    timestamps()
  end

  def changeset(target_band, attrs) do
    target_band
    |> cast(attrs, [])
    |> validate_required([])
    |> foreign_key_constraint(:target_id)
  end
end
