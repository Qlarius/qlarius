defmodule Qlarius.Repo.Migrations.CreateReferralClicks do
  use Ecto.Migration

  def change do
    create table(:referral_clicks) do
      add :referral_id, references(:referrals, on_delete: :delete_all), null: false
      add :ad_event_id, references(:ad_events, on_delete: :delete_all), null: false
      add :referral_credit_id, :bigint, null: true

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:referral_clicks, [:referral_id])
    create index(:referral_clicks, [:referral_credit_id])
    create unique_index(:referral_clicks, [:ad_event_id])
  end
end
