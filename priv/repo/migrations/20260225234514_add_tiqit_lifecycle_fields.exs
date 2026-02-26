defmodule Qlarius.Repo.Migrations.AddTiqitLifecycleFields do
  use Ecto.Migration

  def change do
    # Tiqit lifecycle fields
    alter table(:tiqits) do
      add :disconnected_at, :utc_datetime
      add :undone_at, :utc_datetime
    end

    # Make me_file_id nullable for fleet (disconnect) support.
    # Also change on_delete from delete_all to nilify_all so that
    # deleting a user account anonymizes tiqits rather than deleting them.
    execute(
      "ALTER TABLE tiqits ALTER COLUMN me_file_id DROP NOT NULL",
      "ALTER TABLE tiqits ALTER COLUMN me_file_id SET NOT NULL"
    )

    execute(
      "ALTER TABLE tiqits DROP CONSTRAINT IF EXISTS tiqits_me_file_id_fkey, ADD CONSTRAINT tiqits_me_file_id_fkey FOREIGN KEY (me_file_id) REFERENCES me_files(id) ON DELETE SET NULL",
      "ALTER TABLE tiqits DROP CONSTRAINT IF EXISTS tiqits_me_file_id_fkey, ADD CONSTRAINT tiqits_me_file_id_fkey FOREIGN KEY (me_file_id) REFERENCES me_files(id) ON DELETE CASCADE"
    )

    # User setting for AutoFleet timing
    alter table(:users) do
      add :fleet_after_hours, :integer, default: 24, null: false
    end

    # Catalog settings for undo limit and Tiqit Up
    alter table(:catalogs) do
      add :tiqit_undo_limit, :integer
      add :tiqit_up_enabled, :boolean, default: true, null: false
    end

    # Consumer-creator undo counter (privacy-minimal tracking)
    create table(:consumer_creator_undo_counts) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :creator_id, references(:creators, on_delete: :delete_all), null: false
      add :count, :integer, default: 0, null: false

      timestamps()
    end

    create unique_index(:consumer_creator_undo_counts, [:me_file_id, :creator_id])
  end
end
