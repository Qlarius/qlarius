defmodule Qlarius.Marketing.MediaPiece do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  schema "media_pieces" do
    # belongs_to :marketer
    # belongs_to :media_piece_type

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
    field :active, :boolean
    field :marketer_id, :integer
    field :banner_image, QlariusWeb.Uploaders.ThreeTapBanner.Type

    belongs_to :ad_category, Qlarius.Campaigns.AdCategory

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end

  @doc false
  def changeset(media_piece, attrs) do
    media_piece
    |> cast(attrs, [:title, :body_copy, :display_url, :jump_url, :ad_category_id, :banner_image])
    |> validate_required([:title, :body_copy, :display_url, :jump_url, :ad_category_id])
    |> validate_format(:display_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
    |> validate_format(:jump_url, ~r/^http(s)?:\/\/[\w.-]+(?:\/[\w.-]*)*$/)
    |> cast_attachments(attrs, [:banner_image])
  end
end
