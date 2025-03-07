defmodule Qlarius.Repo.Migrations.CreateTraits do
  use Ecto.Migration

  def change do
    create table(:traits) do
      add :name, :text, null: false
      add :campaign_only, :boolean
      add :numeric, :boolean
      add :immutable, :boolean
      add :taggable, :boolean
      add :is_date, :boolean
      add :active, :boolean
      add :input_type, :string

      timestamps(type: :utc_datetime)
    end

    create table(:trait_values) do
      add :trait_id, references(:traits, on_delete: :delete_all)
      add :name, :text, null: false
      add :display_order, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:trait_values, :trait_id)

    create table(:user_traits) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :trait_id, references(:traits, on_delete: :delete_all)
    end

    create index(:user_traits, :user_id)
    create index(:user_traits, :trait_id)
    create unique_index(:user_traits, [:user_id, :trait_id])
  end
end
