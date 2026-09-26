defmodule Qlarius.Repo.Migrations.AddIsSkippedTagToTraits do
  use Ecto.Migration

  def up do
    alter table(:traits) do
      add :is_skipped_tag, :boolean, null: false, default: false
    end

    execute """
    UPDATE traits AS t
    SET is_skipped_tag = true
    FROM (
      SELECT DISTINCT ON (parent_trait_id) id
      FROM traits
      WHERE parent_trait_id IS NOT NULL
        AND is_active = true
        AND trait_name = 'Prefer not to say'
      ORDER BY parent_trait_id, id
    ) AS chosen
    WHERE t.id = chosen.id
    """

    create unique_index(:traits, [:parent_trait_id],
             name: :traits_one_active_skipped_tag_per_parent,
             where: "is_skipped_tag = true AND is_active = true AND parent_trait_id IS NOT NULL"
           )
  end

  def down do
    drop_if_exists index(:traits, [:parent_trait_id],
                     name: :traits_one_active_skipped_tag_per_parent
                   )

    alter table(:traits) do
      remove :is_skipped_tag
    end
  end
end
