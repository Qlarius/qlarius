defmodule Qlarius.Repo.Migrations.AddUniqueIndexToSurveyCategoryName do
  use Ecto.Migration

  def up do
    execute """
    UPDATE survey_categories
    SET survey_category_name = survey_category_name || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0')
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM survey_categories
      GROUP BY survey_category_name
    )
    """

    create unique_index(:survey_categories, [:survey_category_name])
  end

  def down do
    drop index(:survey_categories, [:survey_category_name])
  end
end
