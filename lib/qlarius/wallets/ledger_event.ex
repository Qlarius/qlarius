defmodule Qlarius.Wallets.LedgerEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Accounts.User

  @primary_key {:id, :id, autogenerate: true}
  # Match migration which uses default column names (inserted_at/updated_at)
  # and utc_datetime storage type
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ["pending", "processing", "completed", "failed"]

  schema "ledger_events" do
    field :amount, :decimal
    field :status, :string, default: "pending"
    field :description, :string

    belongs_to :from_ledger, LedgerHeader, foreign_key: :from_ledger_id
    belongs_to :to_ledger, LedgerHeader, foreign_key: :to_ledger_id
    belongs_to :requested_by_user, User, foreign_key: :requested_by_user_id

    timestamps()
  end

  def changeset(ledger_event, attrs) do
    ledger_event
    |> cast(attrs, [
      :amount,
      :status,
      :description,
      :from_ledger_id,
      :to_ledger_id,
      :requested_by_user_id
    ])
    |> validate_required([
      :amount,
      :from_ledger_id,
      :to_ledger_id,
      :requested_by_user_id
    ])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:from_ledger_id)
    |> foreign_key_constraint(:to_ledger_id)
    |> foreign_key_constraint(:requested_by_user_id)
  end
end
