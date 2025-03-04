defmodule Qlarius.LedgerHeader do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.User

  schema "ledger_headers" do
    field :description, :string
    field :balance, :decimal

    belongs_to :user, User

    timestamps()
  end
end
