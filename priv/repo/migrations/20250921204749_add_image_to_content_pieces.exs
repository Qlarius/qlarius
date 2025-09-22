defmodule Qlarius.Repo.Migrations.AddImageToContentPieces do
  use Ecto.Migration

  def change do
    alter table(:content_pieces) do
      add :image, :string
    end
  end
end
