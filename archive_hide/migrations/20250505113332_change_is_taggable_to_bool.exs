defmodule Qlarius.Repo.Migrations.ChangeIsTaggableToBool do
  use Ecto.Migration

  def up do
    for table <- ["traits", "trait_values"] do
      execute """
        DO $$
        BEGIN
        ALTER TABLE #{table}
        ADD COLUMN is_taggable_tmp BOOLEAN;

        UPDATE #{table}
        SET is_taggable_tmp = (is_taggable = 1);

        ALTER TABLE #{table}
        DROP COLUMN is_taggable;

        ALTER TABLE #{table}
        RENAME COLUMN is_taggable_tmp TO is_taggable;

        ALTER TABLE #{table}
        ALTER COLUMN is_taggable SET NOT NULL;
        END $$
      """
    end
  end
end
