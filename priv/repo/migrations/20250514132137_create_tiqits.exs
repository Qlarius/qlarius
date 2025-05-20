defmodule Qlarius.Repo.Migrations.CreateTiqits do
  use Ecto.Migration

  def change do
    create table(:tiqits) do
      add :tiqit_class_id, references(:tiqit_classes)
      add :me_file_id, references(:me_files, on_delete: :delete_all)
      add :preserved, :boolean, default: false, null: false
      add :purchased_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps()
    end
  end
end
