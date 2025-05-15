# After you've run the migration, run these two commands to copy the data:
#
# INSERT INTO trait_values
# SELECT *
# FROM traits
# WHERE traits.parent_trait_id IS NOT NULL;
#
# DELETE FROM traits WHERE parent_trait_id is NOT NULL;
defmodule Qlarius.Repo.Migrations.CreateTraitValues do
  use Ecto.Migration

  def change do
    execute """
      CREATE TABLE trait_values (
        LIKE traits
      );
      """,
      "DROP TABLE trait_values;"

      execute """
      ALTER TABLE trait_values
      ALTER COLUMN parent_trait_id SET NOT NULL;
      """, ""

      execute """
      ALTER TABLE trait_values
      ADD CONSTRAINT fk_parent_trait_id
      FOREIGN KEY (parent_trait_id)
      REFERENCES traits (id)
      ON DELETE CASCADE;
      """, ""
  end
end
