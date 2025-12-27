defmodule Qlarius.Wallets.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Sponster.AdEvent
  alias Qlarius.Tiqit.Arcade.Tiqit

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ledger_entries" do
    field :amt, :decimal
    field :running_balance, :decimal
    field :description, :string
    field :meta_1, :string

    belongs_to :ledger_header, LedgerHeader
    belongs_to :ad_event, AdEvent
    belongs_to :tiqit, Tiqit

    timestamps()
  end

  def changeset(ledger_entry, attrs) do
    ledger_entry
    |> cast(attrs, [
      :amt,
      :running_balance,
      :description,
      :meta_1,
      :ledger_header_id,
      :ad_event_id,
      :tiqit_id
    ])
    |> validate_required([
      :amt,
      :running_balance,
      :description,
      :ledger_header_id
    ])
    |> foreign_key_constraint(:ledger_header_id)
    |> foreign_key_constraint(:ad_event_id)
    |> foreign_key_constraint(:tiqit_id)
  end
end
