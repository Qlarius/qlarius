defmodule Qlarius.Repo.Migrations.CreateArcadeTables do
  use Ecto.Migration

  def change do
    create table(:content) do
      add :title, :text, null: false
      add :description, :text
      add :content_type, :text, null: false
      add :date_published, :date, null: false
      add :length, :integer, null: false
      add :preview_length, :integer, null: false
      add :file_url, :text, null: false
      add :preview_url, :text, null: false
      add :price_default, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create table(:ticket_types) do
      add :content_id, references(:content, on_delete: :nothing)
      add :name, :string, null: false
      add :duration_seconds, :integer, null: false
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:ticket_types, [:content_id])

    create table(:tickets) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :content_id, references(:content, on_delete: :nothing), null: false
      add :ticket_type_id, references(:ticket_types, on_delete: :nothing), null: false
      add :purchase_timestamp, :utc_datetime, null: false
      add :expiration_timestamp, :utc_datetime, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:tickets, [:user_id])
    create index(:tickets, [:content_id])
    create index(:tickets, [:ticket_type_id])
    create index(:tickets, [:expiration_timestamp])
  end
end
