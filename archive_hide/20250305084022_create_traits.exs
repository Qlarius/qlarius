defmodule Qlarius.Repo.Migrations.CreateTraits do
  use Ecto.Migration

  def change do
    create table(:traits) do
      add :name, :text, null: false
      add :campaign_only, :boolean
      add :numeric, :boolean
      add :immutable, :boolean
      add :display_order, :integer, null: false, default: 1
      add :taggable, :boolean
      add :is_date, :boolean
      add :active, :boolean
      add :input_type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:traits, :display_order)

    create table(:trait_values) do
      add :trait_id, references(:traits, on_delete: :delete_all)
      add :name, :text, null: false
      add :display_order, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:trait_values, :trait_id)

    create table(:user_trait_values) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :trait_value_id, references(:trait_values, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:user_trait_values, :user_id)
    create index(:user_trait_values, :trait_value_id)
    create unique_index(:user_trait_values, [:user_id, :trait_value_id])
  end
end
