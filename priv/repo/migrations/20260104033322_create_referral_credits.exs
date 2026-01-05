defmodule Qlarius.Repo.Migrations.CreateReferralCredits do
  use Ecto.Migration

  def change do
    create table(:referral_credits) do
      add :referral_id, references(:referrals, on_delete: :delete_all), null: false
      add :ledger_entry_id, references(:ledger_entries, on_delete: :delete_all), null: false
      add :clicks_paid_count, :integer, null: false
      add :amount_paid, :decimal, precision: 10, scale: 2, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:referral_credits, [:referral_id])
    create unique_index(:referral_credits, [:ledger_entry_id])
  end
end
