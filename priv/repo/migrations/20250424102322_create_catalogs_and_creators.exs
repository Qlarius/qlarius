defmodule Qlarius.Repo.Migrations.CreateCatalogsAndCreators do
  use Ecto.Migration

  def change do
    create table(:creators) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    create table(:catalogs) do
      add :creator_id, references(:creators, on_delete: :nothing)
      add :name, :string
      add :url, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:catalogs, [:creator_id])

    alter table(:content_pieces) do
      add :type, :string
    end
  end
end
