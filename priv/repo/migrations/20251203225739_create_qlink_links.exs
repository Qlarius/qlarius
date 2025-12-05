defmodule Qlarius.Repo.Migrations.CreateQlinkLinks do
  use Ecto.Migration

  def change do
    create table(:qlink_links) do
      add :qlink_page_id, references(:qlink_pages, on_delete: :delete_all), null: false
      add :qlink_section_id, references(:qlink_sections, on_delete: :nilify_all)
      add :type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :url, :string, null: false
      add :thumbnail, :string
      add :embed_config, :map
      add :display_order, :integer, null: false
      add :is_visible, :boolean, default: true
      add :icon, :string
      add :click_count, :integer, default: 0

      timestamps()
    end

    create index(:qlink_links, [:qlink_page_id])
    create index(:qlink_links, [:qlink_section_id])
  end
end
