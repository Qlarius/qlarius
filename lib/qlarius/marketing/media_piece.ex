defmodule Qlarius.Marketing.MediaPiece do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  schema "media_pieces" do
    belongs_to :marketer, Qlarius.Accounts.Marketer
    belongs_to :media_piece_type, Qlarius.Marketing.MediaPieceType

    field :title, :string
    field :display_url, :string
    field :body_copy, :string
    field :resource_url_old, :string
    field :resource_url, :string
    field :resource_file_name, :string
    field :resource_content_type, :string
    field :resource_file_size, :integer
    field :resource_updated_at, :utc_datetime
    field :duration, :integer
    field :jump_url, :string
    field :active, :boolean, default: true
    field :banner_image, QlariusWeb.Uploaders.ThreeTapBanner.Type

    belongs_to :ad_category, Qlarius.Campaigns.AdCategory

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  # When we create a new media piece, we don't know the ID yet, so we save it
  # first then cast the banner_image in a separate update (using update_changeset)
  def create_changeset(media_piece, attrs) do
    whitelist = ~w[title body_copy display_url jump_url ad_category_id marketer_id]a

    media_piece
    |> cast(attrs, whitelist)
    |> validate_required(whitelist)
    |> validate_format(:display_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
    |> validate_format(:jump_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
  end

  def update_changeset(media_piece, attrs) do
    media_piece
    |> create_changeset(attrs)
    |> cast_attachments(attrs, [:banner_image])
  end
end
