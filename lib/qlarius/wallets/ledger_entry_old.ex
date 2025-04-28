defmodule Qlarius.Wallets.LedgerEntryOld do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Wallets.LedgerHeader, as: LedgerHeader
  alias Qlarius.AdEvent

  schema "ledger_entries" do
    field :amount, :decimal
    field :running_balance, :decimal
    field :description, :string

    belongs_to :ad_event, AdEvent
    belongs_to :ledger_header, LedgerHeader

    timestamps()
  end
end
