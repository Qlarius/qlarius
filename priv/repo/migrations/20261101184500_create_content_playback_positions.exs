defmodule Qlarius.Repo.Migrations.CreateContentPlaybackPositions do
  use Ecto.Migration

  def change do
    create table(:content_playback_positions) do
      add :tiqit_id, references(:tiqits, on_delete: :delete_all), null: false
      add :content_piece_id, references(:content_pieces, on_delete: :delete_all), null: false
      add :position_seconds, :integer, null: false, default: 0
      add :duration_seconds, :integer
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:content_playback_positions, [:tiqit_id, :content_piece_id])
  end
end
