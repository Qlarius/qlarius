defmodule Qlarius.Sponster.Campaigns.TargetBand do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.{Offer, AdEvent}
  alias Qlarius.Sponster.Campaigns.{Target, TargetBandTraitGroup, TargetPopulation}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "target_bands" do
    belongs_to :target, Target

    field :is_bullseye, :string
    field :user_created_by, :integer

    has_many :target_band_trait_groups, TargetBandTraitGroup
    has_many :trait_groups, through: [:target_band_trait_groups, :trait_group]
    has_many :target_populations, TargetPopulation
    has_many :me_files, through: [:target_populations, :me_file]
    has_many :offers, Offer
    has_many :ad_events, AdEvent

    timestamps()
  end

  def changeset(target_band, attrs) do
    target_band
    |> cast(attrs, [:target_id, :is_bullseye, :user_created_by])
    |> validate_required([:target_id])
    |> validate_inclusion(:is_bullseye, ["0", "1"])
    |> foreign_key_constraint(:target_id)
  end

  def is_bullseye?(target_band) do
    target_band.is_bullseye == "1"
  end

  def set_bullseye(_target_band, is_bullseye) when is_boolean(is_bullseye) do
    if is_bullseye, do: "1", else: "0"
  end
end
