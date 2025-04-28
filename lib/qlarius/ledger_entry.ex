defmodule Qlarius.Wallets.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "ledger_entries" do
    field :amt, :decimal
    field :description, :string
    field :is_payable, :boolean
    field :running_balance, :decimal
    field :running_balance_payable, :decimal
    belongs_to :ledger_header, Qlarius.Accounts.LedgerHeader
    belongs_to :ad_event, Qlarius.Accounts.AdEvent
    belongs_to :transfer_event, Qlarius.Accounts.TransferEvent
    belongs_to :payout_event, Qlarius.Accounts.PayoutEvent

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end
end
