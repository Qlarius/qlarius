defmodule Qlarius.Repo.Migrations.CreateContentImpressionDaily do
  use Ecto.Migration

  def change do
    create table(:content_impression_daily) do
      add :date, :date, null: false
      add :content_piece_id, references(:content_pieces, on_delete: :delete_all), null: false
      add :surface, :string, null: false
      add :target_band_id, references(:target_bands, on_delete: :nilify_all)
      add :impressions, :integer, null: false, default: 0
      add :clicks, :integer, null: false, default: 0

      timestamps(updated_at: false)
    end

    create index(:content_impression_daily, [:date, :content_piece_id, :surface])
  end
end
