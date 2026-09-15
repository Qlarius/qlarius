defmodule Qlarius.Repo.Migrations.AddMeFileTagsTraitCompositeIndex do
  use Ecto.Migration

  # `me_file_tags` carries ~601k rows and, apart from its primary key, has no
  # indexes at all — not even on `me_file_id` or `trait_id`. Every correlated
  # EXISTS in PopulateTargetWorker and SyncMeFileToTargetPopulationsWorker is
  # therefore a sequential scan, and those workers stack one per trait group.
  #
  # (trait_id, me_file_id) serves both shapes: "which me_files hold this trait"
  # for the batch populate, and "does this me_file hold a trait from this group"
  # for the incremental sync, which can be answered from the index alone.
  #
  # Built CONCURRENTLY so the table keeps taking writes during deploy — it is on
  # the live tagging path. That requires running outside a transaction, which is
  # why this is its own migration.

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:me_file_tags, [:trait_id, :me_file_id], concurrently: true)
  end
end
