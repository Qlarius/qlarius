defmodule Qlarius.Tiqit.ContentImpressionDaily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_impression_daily" do
    field :date, :date
    field :surface, :string
    field :impressions, :integer, default: 0
    field :clicks, :integer, default: 0

    belongs_to :content_piece, Qlarius.Tiqit.Arcade.ContentPiece
    belongs_to :target_band, Qlarius.Sponster.Campaigns.TargetBand

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(row, attrs) do
    row
    |> cast(attrs, [:date, :surface, :impressions, :clicks, :content_piece_id, :target_band_id])
    |> validate_required([:date, :surface, :content_piece_id])
  end
end
