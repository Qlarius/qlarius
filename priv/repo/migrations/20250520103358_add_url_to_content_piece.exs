defmodule Qlarius.Repo.Migrations.AddUrlToContentPiece do
  use Ecto.Migration

  def change do
    alter table(:content_pieces) do
      add :youtube_id, :string, default: "dQw4w9WgXcQ", null: false
    end
  end
end
