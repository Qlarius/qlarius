defmodule Qlarius.Repo.Migrations.SimplifyReferralTracking do
  use Ecto.Migration

  def change do
    alter table(:referral_clicks) do
      remove :referral_credit_id
    end

    alter table(:referral_credits) do
      remove :amount_paid
      modify :ledger_entry_id, :bigint, null: true
    end

    drop_if_exists unique_index(:referral_credits, [:ledger_entry_id])
  end
end
