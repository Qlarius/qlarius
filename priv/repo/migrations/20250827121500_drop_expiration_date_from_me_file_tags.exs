defmodule Qlarius.Repo.Migrations.DropExpirationDateFromMeFileTags do
  use Ecto.Migration

  def up do
    # Use raw SQL so the migration is idempotent and safe even if the column
    # was already removed manually. Postgres' IF EXISTS prevents errors when the
    # table or column does not exist at migration time.
    execute "ALTER TABLE IF EXISTS me_file_tags DROP COLUMN IF EXISTS expiration_date"
  end

  def down do
    # Restore the column as NULLable if you ever need to roll back. IF NOT EXISTS
    # prevents errors if the column is already present for any reason.
    # Note: we intentionally do not re-introduce NOT NULL constraints here.
    execute "ALTER TABLE IF EXISTS me_file_tags ADD COLUMN IF NOT EXISTS expiration_date timestamp NULL"
  end
end
