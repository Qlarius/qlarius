defmodule Qlarius.Repo.Migrations.AddSplitReminderToMeFiles do
  use Ecto.Migration

  def change do
    alter table(:me_files) do
      add :split_reminder_dismissed_at, :utc_datetime
      add :split_reminder_shown_count, :integer, default: 0, null: false
    end
  end
end
