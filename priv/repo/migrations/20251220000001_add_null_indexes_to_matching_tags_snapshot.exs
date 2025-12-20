defmodule Qlarius.Repo.Migrations.AddNullIndexesToMatchingTagsSnapshot do
  use Ecto.Migration

  def up do
    create index(:target_populations, [:id],
             where: "matching_tags_snapshot IS NULL",
             name: :target_populations_null_snapshot_idx
           )

    create index(:offers, [:me_file_id, :target_band_id],
             where: "matching_tags_snapshot IS NULL",
             name: :offers_null_snapshot_idx
           )

    create index(:ad_events, [:me_file_id, :target_band_id],
             where: "matching_tags_snapshot IS NULL",
             name: :ad_events_null_snapshot_idx
           )
  end

  def down do
    drop_if_exists index(:target_populations, [:id],
                     name: :target_populations_null_snapshot_idx
                   )

    drop_if_exists index(:offers, [:me_file_id, :target_band_id],
                     name: :offers_null_snapshot_idx
                   )

    drop_if_exists index(:ad_events, [:me_file_id, :target_band_id],
                     name: :ad_events_null_snapshot_idx
                   )
  end
end
