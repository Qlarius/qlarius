defmodule Qlarius.Repo.Migrations.AddUniqueIndexToTraitCategoryName do
  use Ecto.Migration

  def up do
    execute """
    UPDATE trait_categories
    SET trait_category_name = trait_category_name || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0')
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM trait_categories
      GROUP BY trait_category_name
    )
    """

    create unique_index(:trait_categories, [:trait_category_name])
  end

  def down do
    drop index(:trait_categories, [:trait_category_name])
  end
end
