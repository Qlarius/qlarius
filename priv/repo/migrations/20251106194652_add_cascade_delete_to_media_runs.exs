defmodule Qlarius.Repo.Migrations.AddCascadeDeleteToMediaRuns do
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'media_runs_media_sequence_id_fkey'
        AND table_name = 'media_runs'
      ) THEN
        ALTER TABLE media_runs DROP CONSTRAINT media_runs_media_sequence_id_fkey;
      END IF;
    END $$;
    """

    execute """
    DELETE FROM media_runs
    WHERE media_sequence_id NOT IN (SELECT id FROM media_sequences)
    """

    execute """
    ALTER TABLE media_runs
    ADD CONSTRAINT media_runs_media_sequence_id_fkey
    FOREIGN KEY (media_sequence_id)
    REFERENCES media_sequences(id)
    ON DELETE CASCADE
    """
  end

  def down do
    execute "ALTER TABLE media_runs DROP CONSTRAINT media_runs_media_sequence_id_fkey"

    execute """
    ALTER TABLE media_runs
    ADD CONSTRAINT media_runs_media_sequence_id_fkey
    FOREIGN KEY (media_sequence_id)
    REFERENCES media_sequences(id)
    """
  end
end
