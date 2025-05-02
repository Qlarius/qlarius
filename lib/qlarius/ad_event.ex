defmodule Qlarius.AdEvent do
  use Ecto.Schema

  schema "ad_events" do
    field :offer_amount, :decimal
    field :is_throttled, :boolean, default: false
    field :is_offer_complete, :boolean, default: false
    field :ip_address, :string
    field :is_demo, :boolean
    field :url, :string

    belongs_to :offer, Qlarius.Offer
    belongs_to :me_file, Qlarius.Accounts.MeFile
    belongs_to :campaign, Qlarius.Campaigns.Campaign
    belongs_to :media_run, Qlarius.Marketing.MediaRun

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end
end
