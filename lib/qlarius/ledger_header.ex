defmodule Qlarius.Wallets.LedgerHeader do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "ledger_headers" do
    field :description, :string
    field :balance, :decimal
    field :balance_payable, :decimal
    belongs_to :me_file, Qlarius.Accounts.MeFile
    belongs_to :campaign, Qlarius.Accounts.Campaign
    belongs_to :recipient, Qlarius.Accounts.Recipient
    belongs_to :marketer, Qlarius.Accounts.Marketer

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end
end
