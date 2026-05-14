defmodule Qlarius.Repo.Migrations.AddSourceToContentPieces do
  use Ecto.Migration

  def change do
    alter table(:content_pieces) do
      add :source_provider, :string
      add :source_url, :string
      add :source_imported_at, :utc_datetime
    end

    create index(:content_pieces, [:source_provider])
  end
end
