defmodule Qlarius.Repo.Migrations.ConvertMatchingTagsSnapshotToJsonb do
  use Ecto.Migration

  def up do
    execute("UPDATE offers SET matching_tags_snapshot = NULL")
    execute("UPDATE ad_events SET matching_tags_snapshot = NULL")

    execute("ALTER TABLE offers ALTER COLUMN matching_tags_snapshot TYPE jsonb USING matching_tags_snapshot::jsonb")
    execute("ALTER TABLE ad_events ALTER COLUMN matching_tags_snapshot TYPE jsonb USING matching_tags_snapshot::jsonb")

    create index(:offers, [:matching_tags_snapshot], using: :gin)
    create index(:ad_events, [:matching_tags_snapshot], using: :gin)
  end

  def down do
    drop_if_exists index(:offers, [:matching_tags_snapshot])
    drop_if_exists index(:ad_events, [:matching_tags_snapshot])

    execute("ALTER TABLE offers ALTER COLUMN matching_tags_snapshot TYPE varchar USING matching_tags_snapshot::text")
    execute("ALTER TABLE ad_events ALTER COLUMN matching_tags_snapshot TYPE varchar USING matching_tags_snapshot::text")
  end
end
