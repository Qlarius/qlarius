defmodule Qlarius.Repo.Migrations.CreateTraits do
  use Ecto.Migration

  def change do
    create table(:traits) do
      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:user_traits) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :trait_id, references(:traits, on_delete: :delete_all)
    end

    create index(:user_traits, :user_id)
    create index(:user_traits, :trait_id)
    create unique_index(:user_traits, [:user_id, :trait_id])
  end
end
