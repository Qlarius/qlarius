defmodule Qlarius.Repo.Migrations.AddReferralCreditFkToReferralClicks do
  use Ecto.Migration

  def change do
    alter table(:referral_clicks) do
      modify :referral_credit_id, references(:referral_credits, on_delete: :nilify_all),
        from: :bigint
    end
  end
end
