defmodule Qlarius.Repo.Migrations.AddVideoFileToMediaPieces do
  use Ecto.Migration

  def change do
    alter table(:media_pieces) do
      add :video_file, :string
    end
  end
end
