defmodule Qlarius.Repo.Migrations.AddUniqueIndexToAdCategoryName do
  use Ecto.Migration

  def up do
    execute """
    UPDATE ad_categories
    SET ad_category_name = ad_category_name || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0')
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM ad_categories
      GROUP BY ad_category_name
    )
    """

    create unique_index(:ad_categories, [:ad_category_name])
  end

  def down do
    drop index(:ad_categories, [:ad_category_name])
  end
end
