defmodule Qlarius.Legacy.MediaPiece do
  use Ecto.Schema
  import Ecto.Changeset
  use Waffle.Ecto.Schema

  alias Qlarius.Legacy.{MediaPieceType, AdCategory}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "media_pieces" do
    field :title, :string
    field :body_copy, :string
    field :display_url, :string
    field :jump_url, :string
    field :active, :boolean
    field :marketer_id, :integer
    field :duration, :integer
    field :banner_image, QlariusWeb.ThreeTapBanner.Type

    belongs_to :media_piece_type, MediaPieceType
    belongs_to :ad_category, AdCategory

    has_many :media_runs, Qlarius.Legacy.MediaRun
    has_many :offers, through: [:media_runs, :offers]

    timestamps()
  end

  def changeset(media_piece, attrs) do
    media_piece
    |> cast(attrs, [
      :title,
      :body_copy,
      :display_url,
      :jump_url,
      :active,
      :marketer_id,
      :media_piece_type_id,
      :ad_category_id,
      :duration,
      :banner_image
    ])
    |> validate_required([
      :title,
      :display_url,
      :jump_url,
      :media_piece_type_id,
      :ad_category_id,
      :marketer_id,
      :active
    ])
    |> foreign_key_constraint(:media_piece_type_id)
    |> foreign_key_constraint(:ad_category_id)
    |> foreign_key_constraint(:marketer_id)
    |> cast_attachments(attrs, [:banner_image])
  end
end
