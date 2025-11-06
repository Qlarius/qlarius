defmodule Qlarius.Repo.Migrations.AddArchivedAtToMediaSequences do
  use Ecto.Migration

  def change do
    alter table(:media_sequences) do
      add :archived_at, :naive_datetime
    end
  end
end
