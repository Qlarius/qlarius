defmodule Qlarius.AdEvent do
  use Ecto.Schema

  alias Qlarius.Offer

  schema "ad_events" do
    belongs_to :offer, Offer
    has_one :media_piece, through: [:offer, :media_piece]
    has_one :media_run, through: [:offer, :media_run]

    field :offer_amount, :decimal
    field :throttled, :boolean, default: false
    field :demo, :boolean, default: false
    field :offer_complete, :boolean, default: false
    field :ip_address, :string
    field :url, :string

    timestamps()
  end
end
