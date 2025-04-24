defmodule Qlarius.Repo.Migrations.CreateCatalogsAndCreators do
  use Ecto.Migration

  def change do
    create table(:creators) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    create table(:catalogs) do
      add :creator_id, references(:creators, on_delete: :delete_all)
      add :name, :string
      add :url, :string
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:catalogs, [:creator_id])

    drop index(:content_groups, :creator_id)

    alter table(:content_groups) do
      remove :creator_id, references(:users)
      add :catalog_id, references(:catalogs, on_delete: :delete_all)
    end

    create index(:content_groups, [:catalog_id])

    drop index(:content_pieces, :creator_id)

    alter table(:content_pieces) do
      add :type, :string
      remove :creator_id, references(:users), null: false
    end
  end
end
