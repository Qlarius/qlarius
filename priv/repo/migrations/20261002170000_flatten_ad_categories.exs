defmodule Qlarius.Repo.Migrations.FlattenAdCategories do
  use Ecto.Migration

  def up do
    drop_if_exists index(:ad_categories, [:ad_category_name])

    rename table(:ad_categories), :ad_category_name, to: :ad_label

    alter table(:ad_categories) do
      add :row_id, :string
      add :category_id, :string
      add :category_name, :string
      add :category_label, :string
      add :age_gated, :boolean, null: false, default: false
      add :age_min, :smallint
      add :sales_channel_default, :string
      add :meta_1, :text
      add :meta_2, :text
      add :meta_3, :text
      add :sort_order, :integer
      add :cohort, :string
      add :active, :boolean, null: false, default: true
    end

    execute """
    UPDATE ad_categories AS ac
    SET row_id = 'LEGACY-' || lpad(numbered.n::text, 3, '0'),
        category_id = 'LEGACY',
        category_name = 'Legacy',
        category_label = 'Legacy',
        cohort = 'legacy',
        sort_order = 100000 + numbered.n * 10
    FROM (SELECT id, row_number() OVER (ORDER BY id) AS n FROM ad_categories) AS numbered
    WHERE ac.id = numbered.id
    """

    for column <- ~w(row_id category_id category_name category_label cohort sort_order) do
      execute "ALTER TABLE ad_categories ALTER COLUMN #{column} SET NOT NULL"
    end

    create unique_index(:ad_categories, [:row_id])
    create unique_index(:ad_categories, [:ad_label])
    create index(:ad_categories, [:category_id])
    create index(:ad_categories, [:cohort])

    create constraint(:ad_categories, :ad_categories_age_min_check,
             check: "age_min IS NULL OR age_min IN (18, 21)"
           )

    create constraint(:ad_categories, :ad_categories_sales_channel_default_check,
             check:
               "sales_channel_default IS NULL OR sales_channel_default IN ('local', 'online', 'both')"
           )

    create constraint(:ad_categories, :ad_categories_cohort_check,
             check: "cohort ~ '^(legacy|[0-9]{6}-[a-z0-9]{4})$'"
           )
  end

  def down do
    drop constraint(:ad_categories, :ad_categories_cohort_check)
    drop constraint(:ad_categories, :ad_categories_sales_channel_default_check)
    drop constraint(:ad_categories, :ad_categories_age_min_check)

    drop index(:ad_categories, [:cohort])
    drop index(:ad_categories, [:category_id])
    drop index(:ad_categories, [:ad_label])
    drop index(:ad_categories, [:row_id])

    alter table(:ad_categories) do
      remove :row_id
      remove :category_id
      remove :category_name
      remove :category_label
      remove :age_gated
      remove :age_min
      remove :sales_channel_default
      remove :meta_1
      remove :meta_2
      remove :meta_3
      remove :sort_order
      remove :cohort
      remove :active
    end

    rename table(:ad_categories), :ad_label, to: :ad_category_name

    create unique_index(:ad_categories, [:ad_category_name])
  end
end
