defmodule Qlarius.Repo.Migrations.AddShowPieceDescriptionsToContentGroups do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :show_piece_descriptions, :boolean, default: true, null: false
    end
  end
end
