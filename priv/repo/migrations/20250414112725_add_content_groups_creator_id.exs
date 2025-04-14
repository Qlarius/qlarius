defmodule Qlarius.Repo.Migrations.AddContentGroupsCreatorId do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :creator_id, references(:users), null: false
    end

    create index(:content_groups, :creator_id)

    alter table(:content_pieces) do
      add :creator_id, references(:users), null: false
    end

    create index(:content_pieces, :creator_id)
  end
end
