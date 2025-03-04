defmodule Qlarius.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.LedgerHeader

  schema "ledger_entries" do
    field :amount, :decimal
    field :description, :string

    belongs_to :ledger_header, LedgerHeader

    timestamps()
  end
end
