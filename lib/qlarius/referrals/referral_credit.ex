defmodule Qlarius.Referrals.ReferralCredit do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Referrals.Referral
  alias Qlarius.Wallets.LedgerEntry

  schema "referral_credits" do
    field :clicks_paid_count, :integer

    belongs_to :referral, Referral
    belongs_to :ledger_entry, LedgerEntry

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(referral_credit, attrs) do
    referral_credit
    |> cast(attrs, [:referral_id, :ledger_entry_id, :clicks_paid_count])
    |> validate_required([:referral_id, :clicks_paid_count])
    |> validate_number(:clicks_paid_count, greater_than: 0)
    |> foreign_key_constraint(:referral_id)
    |> foreign_key_constraint(:ledger_entry_id)
  end
end
