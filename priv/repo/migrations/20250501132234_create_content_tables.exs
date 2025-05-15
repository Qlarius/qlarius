defmodule Qlarius.Repo.Migrations.CreateContentTables do
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

    create index(:catalogs, :creator_id)

    create table(:content_groups) do
      add :catalog_id, references(:catalogs, on_delete: :delete_all)
      add :title, :text, null: false
      add :description, :text
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:content_groups, [:catalog_id])

    create table(:content_pieces) do
      add :content_group_id, references(:content_groups, on_delete: :delete_all), null: false
      add :title, :text, null: false
      add :description, :text
      add :content_type, :text, null: false
      add :date_published, :date, null: false
      add :length, :integer, null: false
      add :preview_length, :integer, null: false
      add :file_url, :text, null: false
      add :preview_url, :text, null: false
      add :price_default, :decimal, precision: 10, scale: 2, null: false
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:content_pieces, :content_group_id)
  end
end
