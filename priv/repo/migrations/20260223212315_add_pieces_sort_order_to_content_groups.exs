defmodule Qlarius.Repo.Migrations.AddPiecesSortOrderToContentGroups do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :pieces_sort_order, :string, default: "desc", null: false
    end
  end
end
