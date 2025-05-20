# Once you've run this migration run priv/repo/copy_data.sh $herokuconnsting
# to copy all the live data from prod.
defmodule Qlarius.Repo.Migrations.LoadLegacySchema do
  use Ecto.Migration

  def up do
    # The SQL file loaded below defines the schema for the old DB from the
    # legacy Rails app.
    #
    # I got the schema directly from the live Heroku database like this:
    #
    #   pg_dump --schema-only $conn > priv/repo/legacy_structure.sql
    #
    # where $conn is the postgres connection string.
    #
    # Then I made some manual modifications to the file to remove:
    #
    # - custom OWNER and GRANT ACCESS stuff.
    # - the 'SET' config from the top and bottom
    # - references to the `schema_migrations` table
    # - 'active_storage' related tables.
    #
    sql = File.read!("#{:code.priv_dir(:qlarius)}/repo/legacy_structure.sql")

    sql
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, "--"))
    |> Enum.join("\n")
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.each(&execute/1)
  end
end
