defmodule Qlarius.LegacyRepo.Migrations.CreateSchemaMigrations do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Drop if exists using Ecto's drop command with explicit prefix
    drop_if_exists table(:schema_migrations, prefix: "public")

    # Create the new table with explicit prefix
    create table(:schema_migrations, prefix: "public", primary_key: false) do
      add :version, :bigint, primary_key: true
      add :inserted_at, :naive_datetime, null: false
    end
  end

  def down do
    drop table(:schema_migrations, prefix: "public")
  end
end
