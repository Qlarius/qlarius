defmodule Qlarius.Repo.Migrations.DropOldReferralTables do
  use Ecto.Migration

  def up do
    drop_if_exists table(:referral_credits), mode: :cascade
    drop_if_exists table(:referral_clicks), mode: :cascade
    drop_if_exists table(:referrals), mode: :cascade
  end

  def down do
  end
end
