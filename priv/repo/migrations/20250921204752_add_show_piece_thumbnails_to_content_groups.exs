defmodule Qlarius.Repo.Migrations.AddShowPieceThumbnailsToContentGroups do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :show_piece_thumbnails, :boolean, default: false, null: false
    end
  end
end
