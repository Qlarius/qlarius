defmodule Qlarius.Wallets.LedgerHeaderOld do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.User
  alias Qlarius.Wallets.LedgerEntry, as: LedgerEntry

  schema "ledger_headers" do
    field :description, :string
    field :balance, :decimal

    belongs_to :user, User
    has_many :entries, LedgerEntry

    timestamps()
  end
end
