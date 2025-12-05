defmodule Qlarius.Repo.Migrations.CreateQlinkSections do
  use Ecto.Migration

  def change do
    create table(:qlink_sections) do
      add :qlink_page_id, references(:qlink_pages, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :display_order, :integer, null: false
      add :is_collapsed, :boolean, default: false
      add :style, :string

      timestamps()
    end

    create index(:qlink_sections, [:qlink_page_id])
  end
end
