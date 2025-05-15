defmodule Qlarius.Repo.Migrations.ChangeActiveToBool do
  use Ecto.Migration

  def up do
    for table <- ["traits", "trait_values"] do
      execute """
        DO $$
        BEGIN
        ALTER TABLE #{table}
        ADD COLUMN active_tmp BOOLEAN;

        UPDATE #{table}
        SET active_tmp = (active = 1);

        ALTER TABLE #{table}
        DROP COLUMN active;

        ALTER TABLE #{table}
        RENAME COLUMN active_tmp TO active;

        ALTER TABLE #{table}
        ALTER COLUMN active SET NOT NULL;
        END $$
      """
    end
  end
end
