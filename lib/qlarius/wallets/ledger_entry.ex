defmodule Qlarius.Wallets.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledger_entries" do
    belongs_to :ledger_header, Qlarius.Wallets.LedgerHeader

    has_one :user, through: [:ledger_header, :me_file, :user]
    # TODO
    # belongs_to :ad_event, AdEvent

    field :amount, :decimal, source: :amt
    field :description, :string
    field :payable, :boolean, source: :is_payable
    field :running_balance, :decimal
    field :running_balance_payable, :decimal

    belongs_to :ad_event, Qlarius.AdEvent
    # belongs_to :transfer_event, Qlarius.Accounts.TransferEvent
    # belongs_to :payout_event, Qlarius.Accounts.PayoutEvent

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  def changeset(ledger_entry, attrs) do
    ledger_entry
    |> cast(attrs, [
      :amount,
      :running_balance,
      :description,
      :ledger_header_id,
      :ad_event_id
    ])
    |> validate_required([
      :amount,
      :running_balance,
      :description,
      :ledger_header_id
    ])
    |> foreign_key_constraint(:ledger_header_id)
    |> foreign_key_constraint(:ad_event_id)
  end
end
