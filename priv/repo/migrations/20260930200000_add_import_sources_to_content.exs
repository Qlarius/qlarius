defmodule Qlarius.Repo.Migrations.AddImportSourcesToContent do
  use Ecto.Migration

  def up do
    alter table(:content_pieces) do
      add :media_type, :string, null: false, default: "youtube"
      add :external_id, :text
      add :season, :integer
      add :episode_number, :integer
      add :episode_type, :string
      modify :source_url, :text, from: :string
    end

    execute "ALTER TABLE content_pieces ALTER COLUMN youtube_id DROP NOT NULL"
    execute "ALTER TABLE content_pieces ALTER COLUMN youtube_id DROP DEFAULT"

    execute """
    UPDATE content_pieces AS p
    SET external_id = p.youtube_id
    FROM (
      SELECT DISTINCT ON (content_group_id, youtube_id) id
      FROM content_pieces
      WHERE youtube_id IS NOT NULL AND youtube_id <> ''
      ORDER BY content_group_id, youtube_id, id
    ) AS chosen
    WHERE p.id = chosen.id
    """

    create unique_index(:content_pieces, [:content_group_id, :external_id],
             name: :content_pieces_group_external_id_index,
             where: "external_id IS NOT NULL"
           )

    alter table(:content_groups) do
      add :source_provider, :string
      add :source_url, :text
      add :feed_url, :text
      add :feed_season, :integer
      add :feed_episode_types, {:array, :string}, null: false, default: []
      add :feed_auto_sync, :boolean, null: false, default: false
      add :last_synced_at, :utc_datetime
    end

    create index(:content_groups, [:feed_auto_sync], where: "feed_auto_sync = true")
  end

  def down do
    drop_if_exists index(:content_groups, [:feed_auto_sync])

    alter table(:content_groups) do
      remove :source_provider
      remove :source_url
      remove :feed_url
      remove :feed_season
      remove :feed_episode_types
      remove :feed_auto_sync
      remove :last_synced_at
    end

    drop_if_exists index(:content_pieces, [:content_group_id, :external_id],
                     name: :content_pieces_group_external_id_index
                   )

    execute "UPDATE content_pieces SET youtube_id = 'dQw4w9WgXcQ' WHERE youtube_id IS NULL"
    execute "ALTER TABLE content_pieces ALTER COLUMN youtube_id SET DEFAULT 'dQw4w9WgXcQ'"
    execute "ALTER TABLE content_pieces ALTER COLUMN youtube_id SET NOT NULL"

    alter table(:content_pieces) do
      remove :media_type
      remove :external_id
      remove :season
      remove :episode_number
      remove :episode_type
      modify :source_url, :string, from: :text
    end
  end
end
