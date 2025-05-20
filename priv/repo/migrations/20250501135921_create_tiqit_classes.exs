defmodule Qlarius.Repo.Migrations.CreateTiqitClasses do
  use Ecto.Migration

  def change do
    create table(:tiqit_classes) do
      add :catalog_id, references(:catalogs, on_delete: :delete_all)
      add :content_group_id, references(:content_groups, on_delete: :delete_all)
      add :content_piece_id, references(:content_pieces, on_delete: :delete_all)

      add :name, :string, null: false
      add :duration_hours, :integer
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :active, :boolean, default: true, null: false

      timestamps()
    end
  end
end
