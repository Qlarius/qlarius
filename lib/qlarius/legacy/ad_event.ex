defmodule Qlarius.Legacy.AdEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Legacy.{Offer, MeFile, Campaign, MediaRun}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ad_events" do
    field :offer_amount, :decimal
    field :is_throttled, :boolean, default: false
    field :is_offer_complete, :boolean, default: false
    field :ip_address, :string
    field :url, :string

    belongs_to :offer, Offer
    belongs_to :me_file, MeFile
    belongs_to :campaign, Campaign
    belongs_to :media_run, MediaRun

    timestamps()
  end

  def changeset(ad_event, attrs) do
    ad_event
    |> cast(attrs, [
      :offer_amount,
      :is_throttled,
      :is_offer_complete,
      :ip_address,
      :url,
      :offer_id,
      :me_file_id,
      :campaign_id,
      :media_run_id
    ])
    |> validate_required([
      :offer_amount,
      :is_throttled,
      :is_offer_complete,
      :offer_id
    ])
    |> foreign_key_constraint(:offer_id)
    |> foreign_key_constraint(:me_file_id)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:media_run_id)
  end
end
