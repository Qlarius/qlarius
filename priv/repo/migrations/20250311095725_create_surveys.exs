defmodule Qlarius.Repo.Migrations.CreateSurveySystem do
  use Ecto.Migration

  def change do
    create table(:survey_categories) do
      add :name, :text, null: false
      add :display_order, :integer, null: false

      timestamps()
    end

    create table(:surveys) do
      add :name, :text, null: false
      add :category_id, references(:survey_categories, on_delete: :restrict), null: false
      add :display_order, :integer, null: false
      add :active, :boolean, default: false

      timestamps()
    end

    create table(:survey_questions) do
      add :text, :text, null: false
      add :active, :boolean, default: true, null: false
      add :display_order, :integer, null: false

      timestamps()
    end

    create table(:survey_question_surveys) do
      add :survey_id, references(:surveys, on_delete: :delete_all), null: false
      add :question_id, references(:survey_questions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:survey_question_surveys, :survey_id)
    create index(:survey_question_surveys, :question_id)
    create unique_index(:survey_question_surveys, [:survey_id, :question_id])

    create table(:survey_answers) do
      add :text, :text, null: false
      add :question_id, references(:survey_questions, on_delete: :delete_all), null: false
      add :trait_id, references(:traits, on_delete: :nilify_all)
      add :display_order, :integer
      add :next_question_id, references(:survey_questions, on_delete: :nilify_all)

      timestamps()
    end

    create index(:surveys, [:category_id])
    create index(:surveys, [:display_order])
    create index(:surveys, [:active])

    create index(:survey_questions, [:display_order])
    create index(:survey_questions, [:active])

    create index(:survey_answers, [:question_id])
    create index(:survey_answers, [:trait_id])
    create index(:survey_answers, [:next_question_id])
    create index(:survey_answers, [:display_order])
  end
end
