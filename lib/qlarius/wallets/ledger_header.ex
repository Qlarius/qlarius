defmodule Qlarius.Wallets.LedgerHeader do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ledger_headers" do
    field :description, :string
    field :balance, :decimal
    field :balance_payable, :decimal

    belongs_to :me_file, Qlarius.YouData.MeFiles.MeFile
    belongs_to :campaign, Qlarius.Sponster.Campaigns.Campaign
    belongs_to :recipient, Qlarius.Sponster.Recipient
    belongs_to :marketer, Qlarius.Accounts.Marketer
    belongs_to :creator, Qlarius.Creators.Creator

    has_many :ledger_entries, Qlarius.Wallets.LedgerEntry

    timestamps()
  end

  def changeset(ledger_header, attrs) do
    ledger_header
    |> cast(attrs, [
      :description,
      :balance,
      :balance_payable,
      :me_file_id,
      :campaign_id,
      :recipient_id,
      :marketer_id,
      :creator_id
    ])
    |> validate_required([:description])
  end
end
