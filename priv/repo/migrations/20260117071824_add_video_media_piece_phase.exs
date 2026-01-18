defmodule Qlarius.Repo.Migrations.AddVideoMediaPiecePhase do
  use Ecto.Migration

  def up do
    execute """
    INSERT INTO media_piece_phases (
      media_piece_type_id,
      phase,
      name,
      "desc",
      is_final_phase,
      created_at,
      updated_at
    )
    VALUES (2, 1, 'view', 'Video View', true, NOW(), NOW());
    """
  end

  def down do
    execute "DELETE FROM media_piece_phases WHERE media_piece_type_id = 2 AND phase = 1;"
  end
end
