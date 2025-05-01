defmodule Qlarius.Repo.Migrations.CreateTargets do
  use Ecto.Migration

  def change do
    create table(:targets) do
      add :name, :text, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create table(:target_bands) do
      add :target_id, references(:targets, on_delete: :delete_all), null: false
      add :title, :text, null: false
      add :description, :text
      add :bullseye, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:target_bands, :target_id)
  end
end
