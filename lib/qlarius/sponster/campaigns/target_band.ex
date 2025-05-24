defmodule Qlarius.Sponster.Campaigns.TargetBand do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.TraitGroup
  alias Qlarius.Sponster.Campaigns.Bid
  alias Qlarius.YouData.MeFiles.MeFile

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "target_bands" do
    belongs_to :target, Target

    has_many :target_band_trait_groups, Qlarius.Sponster.Campaigns.TargetBandTraitGroup
    has_many :trait_groups, through: [:target_band_trait_groups, :trait_group]
    has_many :target_populations, Qlarius.Sponster.Campaigns.TargetPopulation
    has_many :me_files, through: [:target_populations, :me_file]
    has_many :bids, Bid
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
