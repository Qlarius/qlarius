defmodule Qlarius.LegacyRepo.Migrations.AddBannerImageToMediaPieces do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Add banner_image column to media_pieces table with explicit prefix
    alter table(:media_pieces, prefix: "public") do
      add :banner_image, :string
    end
  end

  def down do
    alter table(:media_pieces, prefix: "public") do
      remove :banner_image
    end
  end
end
