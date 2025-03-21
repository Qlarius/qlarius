defmodule Qlarius.Repo.Migrations.CreateAdEvents do
  use Ecto.Migration

  def change do
    alter table(:offers) do
      add :throttled, :boolean, null: false, default: false
      add :demo, :boolean, null: false, default: false
      add :current, :boolean, null: false, default: false
      add :jobbed, :boolean, null: false, default: false
    end

    create table(:ad_events) do
      add :offer_id, references(:offers)
      add :offer_bid_amt, :decimal, precision: 8, scale: 2
      add :offer_amount, :decimal, null: false
      add :throttled, :boolean, null: false
      add :demo, :boolean, null: false
      add :offer_complete, :boolean, null: false
      add :ip_address, :string
      add :url, :string

      timestamps()
    end

    alter table(:ledger_entries) do
      add :ad_event_id, references(:ad_events)
      add :running_balance, :decimal, precision: 8, scale: 2, null: false
    end
  end
end
