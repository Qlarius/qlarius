defmodule Qlarius.Repo.Migrations.AddArchivedAtToContentPieces do
  use Ecto.Migration

  def change do
    alter table(:content_pieces) do
      add :archived_at, :utc_datetime
    end

    create index(:content_pieces, [:content_group_id, :archived_at])
  end
end
