defmodule Qlarius.Repo.Migrations.CreateSurveySystem do
  use Ecto.Migration

  def change do
    create table(:survey_categories) do
      add :name, :text, null: false
      add :display_order, :integer, null: false, default: 1

      timestamps()
    end

    create index(:survey_categories, :display_order)

    create table(:surveys) do
      add :name, :text, null: false
      add :category_id, references(:survey_categories, on_delete: :restrict), null: false
      add :display_order, :integer, null: false, default: 1
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:surveys, [:category_id])
    create index(:surveys, [:display_order])
    create index(:surveys, [:active])

    create table(:traits_surveys) do
      add :survey_id, references(:surveys, on_delete: :delete_all), null: false
      add :trait_id, references(:traits, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:traits_surveys, :survey_id)
    create index(:traits_surveys, :trait_id)
    create unique_index(:traits_surveys, [:survey_id, :trait_id])

    alter table(:traits) do
      add :question, :text
    end

    alter table(:trait_values) do
      add :answer, :text
    end
  end
end
