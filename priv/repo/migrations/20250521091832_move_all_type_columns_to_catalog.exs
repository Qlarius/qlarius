defmodule Qlarius.Repo.Migrations.MoveAllTypeColumnsToCatalog do
  use Ecto.Migration

  def change do
    alter table(:catalogs) do
      add :group_type, :string
      add :piece_type, :string
    end

    alter table(:content_groups) do
      remove :type, :string
    end

    alter table(:content_pieces) do
      # Not sure why we had two here; think this was a mistake
      remove :type, :string
      remove :content_type, :string
    end
  end
end
