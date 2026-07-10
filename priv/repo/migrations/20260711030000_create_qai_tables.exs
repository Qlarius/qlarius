defmodule Qlarius.Repo.Migrations.CreateQaiTables do
  use Ecto.Migration

  # Phase 2 (Qai): fleeting chat sessions per MeFile. expires_at is the fleet
  # clock, refreshed on every touch; preserving a session nulls it. Expired
  # sessions and their messages are hard-deleted by an hourly sweep, so the
  # schema never accumulates a retained conversation archive by default.
  def change do
    create table(:qai_sessions) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :title, :string, size: 120
      add :expires_at, :utc_datetime
      add :preserved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:qai_sessions, [:me_file_id, :updated_at])
    create index(:qai_sessions, [:expires_at], where: "expires_at IS NOT NULL")

    create table(:qai_messages) do
      add :qai_session_id, references(:qai_sessions, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false, default: ""
      add :model, :string
      add :stopped, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:qai_messages, [:qai_session_id])
  end
end
