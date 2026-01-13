defmodule Qlarius.Repo.Migrations.CreatePushNotificationsTables do
  use Ecto.Migration

  def change do
    create table(:push_subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subscription_data, :map, null: false
      add :device_type, :string
      add :user_agent, :text
      add :active, :boolean, default: true
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:push_subscriptions, [:user_id])
    create index(:push_subscriptions, [:active])

    create table(:notification_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel, :string, null: false
      add :category, :string, null: false
      add :enabled, :boolean, default: true
      add :preferred_hours, {:array, :integer}, default: []
      add :quiet_hours_start, :time
      add :quiet_hours_end, :time

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notification_preferences, [:user_id, :channel, :category])

    create table(:notification_logs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :notification_type, :string, null: false
      add :channel, :string, null: false
      add :title, :text
      add :body, :text
      add :data, :map
      add :sent_at, :utc_datetime, null: false
      add :delivered_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :failure_reason, :text
    end

    create index(:notification_logs, [:user_id])
    create index(:notification_logs, [:sent_at])
  end
end
