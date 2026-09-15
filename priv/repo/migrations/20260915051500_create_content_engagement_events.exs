defmodule Qlarius.Repo.Migrations.CreateContentEngagementEvents do
  use Ecto.Migration

  def change do
    create table(:content_engagement_events) do
      add :type, :string, null: false
      add :surface, :string, null: false

      add :me_file_id, references(:me_files, on_delete: :nilify_all)
      add :session_id, :string

      add :target_band_id, references(:target_bands, on_delete: :nilify_all)
      add :target_band_id_ss, :bigint
      add :target_id, references(:targets, on_delete: :nilify_all)
      add :target_id_ss, :bigint

      add :matching_tags_snapshot, :map
      add :tier, :integer
      add :population_count, :integer
      add :boost_level, :string
      add :rank_position, :integer

      add :content_piece_id, references(:content_pieces, on_delete: :nilify_all)
      add :content_piece_id_ss, :bigint
      add :content_piece_title_ss, :string
      add :content_group_id, references(:content_groups, on_delete: :nilify_all)
      add :content_group_id_ss, :bigint
      add :catalog_id, references(:catalogs, on_delete: :nilify_all)
      add :catalog_id_ss, :bigint
      add :creator_id, references(:creators, on_delete: :nilify_all)
      add :creator_id_ss, :bigint
      add :creator_name_ss, :string
      add :tiqit_id, references(:tiqits, on_delete: :nilify_all)
      add :tiqit_id_ss, :bigint

      timestamps(updated_at: false)
    end

    create index(:content_engagement_events, [:creator_id_ss, :inserted_at])
    create index(:content_engagement_events, [:content_piece_id_ss, :inserted_at])
    create index(:content_engagement_events, [:target_band_id_ss])
    create index(:content_engagement_events, [:me_file_id])
    create index(:content_engagement_events, [:surface, :inserted_at])

    create constraint(:content_engagement_events, :type_must_be_action,
             check: "type IN ('click', 'preview_start', 'tiqit_purchase', 'content_open')"
           )

    create constraint(:content_engagement_events, :surface_must_be_known,
             check:
               "surface IN ('picked_for_you', 'more_from_creators', 'browse', 'search', 'catalog_page', 'group_page', 'qlink', 'direct')"
           )
  end
end
