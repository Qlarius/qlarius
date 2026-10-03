defmodule Qlarius.Sponster.Ads.MediaPiece do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Sponster.Ads.{MediaPieceType, AdCategory}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  # One line of bold title, and three lines of body, inside the 3-tap text panel.
  @three_tap_title_max 32
  @three_tap_body_max 120

  def three_tap_title_max, do: @three_tap_title_max
  def three_tap_body_max, do: @three_tap_body_max

  schema "media_pieces" do
    field :title, :string
    field :body_copy, :string
    field :display_url, :string
    field :jump_url, :string
    field :active, :boolean
    field :marketer_id, :integer
    field :duration, :integer
    field :banner_image, :string
    field :video_file, :string
    field :video_poster_image, :string
    field :api_ref, :string

    belongs_to :media_piece_type, MediaPieceType
    belongs_to :ad_category, AdCategory

    has_many :media_runs, Qlarius.Sponster.Campaigns.MediaRun
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
      :banner_image,
      :video_file,
      :video_poster_image,
      :api_ref
    ])
    |> validate_required([
      :title,
      :media_piece_type_id,
      :ad_category_id,
      :marketer_id,
      :active
    ])
    |> validate_length(:title, max: 256)
    |> validate_length(:body_copy, max: 1028)
    |> validate_length(:display_url, max: 256)
    |> validate_length(:jump_url, max: 512)
    |> validate_media_type_fields()
    |> validate_ad_category_active()
    |> Qlarius.ApiRef.validate()
    |> foreign_key_constraint(:media_piece_type_id)
    |> foreign_key_constraint(:ad_category_id)
    |> foreign_key_constraint(:marketer_id)
  end

  defp validate_ad_category_active(changeset) do
    validate_change(changeset, :ad_category_id, fn :ad_category_id, id ->
      case Qlarius.Repo.get(AdCategory, id) do
        nil -> [ad_category_id: "does not exist"]
        %AdCategory{active: false} -> [ad_category_id: "is inactive and can't be newly assigned"]
        _ -> []
      end
    end)
  end

  defp validate_media_type_fields(changeset) do
    media_type_id = get_field(changeset, :media_piece_type_id)

    case media_type_id do
      1 ->
        changeset
        |> validate_required([:banner_image, :display_url, :jump_url])
        |> validate_length(:title, max: @three_tap_title_max)
        |> validate_length(:body_copy, max: @three_tap_body_max)

      2 ->
        changeset
        |> validate_required([:video_file, :duration])

      _ ->
        changeset
    end
  end
end
