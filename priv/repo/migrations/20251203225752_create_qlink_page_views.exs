defmodule Qlarius.Repo.Migrations.CreateQlinkPageViews do
  use Ecto.Migration

  def change do
    create table(:qlink_page_views) do
      add :qlink_page_id, references(:qlink_pages, on_delete: :delete_all), null: false
      add :qlink_link_id, references(:qlink_links, on_delete: :delete_all)
      add :event_type, :string, null: false
      add :visitor_fingerprint, :string
      add :session_id, :string
      add :referer, :string
      add :user_agent, :text
      add :country_code, :string
      add :device_type, :string

      timestamps(updated_at: false)
    end

    create index(:qlink_page_views, [:qlink_page_id])
    create index(:qlink_page_views, [:qlink_link_id])
    create index(:qlink_page_views, [:inserted_at])
  end
end
