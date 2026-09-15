defmodule Qlarius.Repo.Migrations.CreateContentAudienceTargets do
  use Ecto.Migration

  # The bridge between a content item and an audience. One target is reusable
  # across many attachments at any level of the creator/catalog/group/piece
  # chain, which is what makes the inheritance model work.
  #
  # `creator_id` here is the *attachment level*, not ownership — ownership is
  # `targets.creator_id`. A creator attaching an audience to their whole
  # catalogue uses `creator_id`; the two are unrelated.

  def change do
    create table(:content_audience_targets) do
      add :target_id, references(:targets, on_delete: :delete_all), null: false
      add :mode, :string, null: false

      add :creator_id, references(:creators, on_delete: :delete_all)
      add :catalog_id, references(:catalogs, on_delete: :delete_all)
      add :content_group_id, references(:content_groups, on_delete: :delete_all)
      add :content_piece_id, references(:content_pieces, on_delete: :delete_all)

      timestamps()
    end

    create index(:content_audience_targets, [:target_id])

    # Extends the three-column pattern in
    # 20250520103235_add_constraints_to_tiqit_classes.exs to four.
    create constraint(:content_audience_targets, :exactly_one_attachment_level_non_null,
             check: """
             (creator_id IS NOT NULL)::int +
             (catalog_id IS NOT NULL)::int +
             (content_group_id IS NOT NULL)::int +
             (content_piece_id IS NOT NULL)::int = 1
             """
           )

    create constraint(:content_audience_targets, :mode_must_be_boost_or_gate,
             check: "mode IN ('boost', 'gate')"
           )

    # At most one boost and one gate per level per content item, so resolution
    # is never ambiguous. Postgres treats NULLs as distinct, so each index only
    # constrains rows actually attached at that level.
    create unique_index(:content_audience_targets, [:mode, :creator_id])
    create unique_index(:content_audience_targets, [:mode, :catalog_id])
    create unique_index(:content_audience_targets, [:mode, :content_group_id])
    create unique_index(:content_audience_targets, [:mode, :content_piece_id])
  end
end
