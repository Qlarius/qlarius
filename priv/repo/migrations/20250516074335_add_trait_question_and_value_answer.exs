defmodule Qlarius.Repo.Migrations.AddTraitQuestionAndValueAnswer do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      add :question, :text
    end

    alter table(:trait_values) do
      add :answer, :text
    end

    create table(:traits_surveys) do
      add :trait_id, references(:traits, on_delete: :delete_all)
      add :survey_id, references(:surveys, on_delete: :delete_all)
    end

    execute """
    INSERT INTO traits_surveys (survey_id, trait_id)
    SELECT DISTINCT sqs.survey_id, tv.parent_trait_id
    FROM survey_question_surveys sqs
    JOIN survey_questions sq ON sqs.survey_question_id = sq.id
    JOIN survey_answers sa ON sq.id = sa.survey_question_id
    JOIN trait_values tv ON sa.trait_id = tv.id;
    """, ""

    execute """
    UPDATE trait_values tv
    SET answer = (
      SELECT sa.text
      FROM survey_answers sa
      WHERE sa.trait_id = tv.id
      ORDER BY COALESCE(sa.modified_date, sa.added_date) DESC
      LIMIT 1
    )
    WHERE EXISTS (
      SELECT 1
      FROM survey_answers sa
      WHERE sa.trait_id = tv.id
    );
    """, ""

    execute """
    UPDATE traits
    SET question = (
      SELECT sq.text
      FROM survey_answers sa
      JOIN survey_questions sq ON sa.survey_question_id = sq.id
      JOIN trait_values tv ON sa.trait_id = tv.id
      WHERE tv.parent_trait_id = traits.id
      ORDER BY COALESCE(sq.modified_date, sq.added_date) DESC
      LIMIT 1
    )
    WHERE EXISTS (
      SELECT 1
      FROM survey_answers sa
      JOIN survey_questions sq ON sa.survey_question_id = sq.id
      JOIN trait_values tv ON sa.trait_id = tv.id
      WHERE tv.parent_trait_id = traits.id
    );
    """, ""
  end
end
