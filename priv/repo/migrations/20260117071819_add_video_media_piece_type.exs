defmodule Qlarius.Repo.Migrations.AddVideoMediaPieceType do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO media_piece_types (id, name, "desc", ad_phase_count_to_complete, created_at, updated_at)
    VALUES (2, 'video_ad', 'Video advertisement', 1, NOW(), NOW());
    """
  end

  def down do
    execute "DELETE FROM media_piece_types WHERE id = 2;"
  end
end
