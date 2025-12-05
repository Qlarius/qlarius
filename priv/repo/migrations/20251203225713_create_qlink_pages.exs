defmodule Qlarius.Repo.Migrations.CreateQlinkPages do
  use Ecto.Migration

  def change do
    create table(:qlink_pages) do
      add :creator_id, references(:creators, on_delete: :delete_all), null: false
      add :alias, :string, null: false
      add :slug, :string, null: false
      add :title, :string
      add :bio_text, :text
      add :profile_photo, :string
      add :social_links, :map
      add :theme_config, :map
      add :background_config, :map
      add :custom_css, :text
      add :is_published, :boolean, default: false
      add :view_count, :integer, default: 0
      add :total_clicks, :integer, default: 0

      timestamps()
    end

    create index(:qlink_pages, [:creator_id])
    create unique_index(:qlink_pages, [:alias])
  end
end
