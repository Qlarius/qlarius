defmodule Qlarius.Repo.Migrations.AddArchivedAtToTargets do
  use Ecto.Migration

  def change do
    alter table(:targets) do
      add :archived_at, :naive_datetime
    end

    create index(:targets, [:marketer_id, :archived_at])
  end
end
