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

    create table(:tiqit_types) do
      add :content_id, references(:content, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :duration_hours, :integer
      add :price, :decimal, precision: 10, scale: 2, null: false
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create constraint(:tiqit_types, :duration_hours_must_be_positive, check: "duration_hours > 0")

    create index(:tiqit_types, [:content_id])

    create table(:tiqits) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tiqit_type_id, references(:tiqit_types, on_delete: :nilify_all), null: false
      add :purchased_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:tiqits, [:user_id])
    create index(:tiqits, [:tiqit_type_id])
    create index(:tiqits, [:expires_at])
  end
end
