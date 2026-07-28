defmodule Qlarius.Repo.Migrations.AddExcludeAccessFlagsToContentPieces do
  use Ecto.Migration

  def change do
    alter table(:content_pieces) do
      add :exclude_from_catalog_access, :boolean, null: false, default: false
      add :exclude_from_group_access, :boolean, null: false, default: false
    end
  end
end
