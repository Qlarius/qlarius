defmodule Qlarius.Repo.Migrations.AddVideoPosterImageToMediaPieces do
  use Ecto.Migration

  def change do
    alter table(:media_pieces) do
      add :video_poster_image, :string
    end
  end
end
