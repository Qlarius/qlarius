defmodule Qlarius.Repo.Migrations.CreateArcadeTables do
  use Ecto.Migration

  def change do
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
