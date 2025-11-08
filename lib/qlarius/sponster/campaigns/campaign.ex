defmodule Qlarius.Sponster.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.Campaigns.{MediaSequence, Target, Bid}
  alias Qlarius.Wallets.LedgerHeader

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  schema "campaigns" do
    field :title, :string
    field :description, :string
    field :start_date, :naive_datetime
    field :end_date, :naive_datetime
    field :is_payable, :boolean
    field :is_throttled, :boolean
    field :is_demo, :boolean
    field :launched_at, :naive_datetime
    field :deactivated_at, :naive_datetime

    belongs_to :marketer, Marketer
    belongs_to :target, Target
    belongs_to :media_sequence, MediaSequence

    has_many :bids, Bid
    has_one :ledger_header, LedgerHeader

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :description,
      :start_date,
      :end_date,
      :is_payable,
      :is_throttled,
      :is_demo,
      :launched_at,
      :deactivated_at
    ])
    |> validate_required([
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :start_date
    ])
  end
end
