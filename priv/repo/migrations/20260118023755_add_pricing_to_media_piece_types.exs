defmodule Qlarius.Repo.Migrations.AddPricingToMediaPieceTypes do
  use Ecto.Migration

  def change do
    alter table(:media_piece_types) do
      add :base_fee, :decimal, precision: 10, scale: 2, null: false, default: 0.10
      add :markup_multiplier, :decimal, precision: 5, scale: 2, null: false, default: 1.50
    end

    # Update existing records
    execute """
    UPDATE media_piece_types
    SET base_fee = CASE
      WHEN id = 1 THEN 0.10  -- 3-Tap
      WHEN id = 2 THEN 0.15  -- Video
      ELSE 0.10
    END,
    markup_multiplier = 1.50
    """, ""
  end
end
