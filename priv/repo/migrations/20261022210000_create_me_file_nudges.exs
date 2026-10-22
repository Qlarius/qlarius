defmodule Qlarius.Repo.Migrations.CreateMeFileNudges do
  use Ecto.Migration

  @setup_keys ~w(essentials tag_goal notifications invite)

  def up do
    create table(:me_file_nudges) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :nudge_key, :string, null: false
      add :completed_at, :utc_datetime
      add :dismissed_at, :utc_datetime
      add :dismissed_until, :utc_datetime
      add :shown_count, :integer, null: false, default: 0
      add :tapped_count, :integer, null: false, default: 0
      add :dismissed_count, :integer, null: false, default: 0
      add :first_shown_at, :utc_datetime
      add :last_shown_at, :utc_datetime
      add :last_tapped_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:me_file_nudges, [:me_file_id, :nudge_key])

    flush()

    # Strong Start kept two hand-set flags and one "Don't show again" choice on
    # me_files. Carry them over so nobody sees a step they already finished or hid.
    execute """
    INSERT INTO me_file_nudges (me_file_id, nudge_key, completed_at, inserted_at, updated_at)
    SELECT id, 'notifications', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
    FROM me_files
    WHERE strong_start_data->>'notifications_configured' = 'true'
    """

    execute """
    INSERT INTO me_file_nudges (me_file_id, nudge_key, completed_at, inserted_at, updated_at)
    SELECT id, 'invite', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
    FROM me_files
    WHERE strong_start_data->>'referral_viewed' = 'true'
    ON CONFLICT (me_file_id, nudge_key) DO NOTHING
    """

    for key <- @setup_keys do
      execute """
      INSERT INTO me_file_nudges (me_file_id, nudge_key, completed_at, inserted_at, updated_at)
      SELECT id, '#{key}', COALESCE(strong_start_completed_at, now() AT TIME ZONE 'utc'),
             now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
      FROM me_files
      WHERE strong_start_status = 'completed'
      ON CONFLICT (me_file_id, nudge_key) DO NOTHING
      """

      execute """
      INSERT INTO me_file_nudges
        (me_file_id, nudge_key, dismissed_at, dismissed_count, inserted_at, updated_at)
      SELECT id, '#{key}', COALESCE(strong_start_completed_at, now() AT TIME ZONE 'utc'), 1,
             now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'
      FROM me_files
      WHERE strong_start_status = 'skipped'
      ON CONFLICT (me_file_id, nudge_key)
      DO UPDATE SET dismissed_at = EXCLUDED.dismissed_at, dismissed_count = 1
      """
    end
  end

  def down do
    drop table(:me_file_nudges)
  end
end
