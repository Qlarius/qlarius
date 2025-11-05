defmodule Qlarius.Repo.Migrations.AddUniqueIndexToTargetPopulations do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM target_populations a USING (
      SELECT MIN(id) as id, target_band_id, me_file_id
      FROM target_populations
      GROUP BY target_band_id, me_file_id
      HAVING COUNT(*) > 1
    ) b
    WHERE a.target_band_id = b.target_band_id
    AND a.me_file_id = b.me_file_id
    AND a.id <> b.id
    """

    create unique_index(:target_populations, [:target_band_id, :me_file_id],
             name: :target_populations_target_band_id_me_file_id_index
           )
  end

  def down do
    drop index(:target_populations, [:target_band_id, :me_file_id],
           name: :target_populations_target_band_id_me_file_id_index
         )
  end
end
