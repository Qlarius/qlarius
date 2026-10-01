defmodule Qlarius.Tiqit.Arcade.ContentPiece do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.TiqitClass

  schema "content_pieces" do
    field :display_order, :integer, default: 0
    field :title, :string
    field :description, :string
    field :date_published, :date
    field :length, :integer, default: 0
    field :preview_length, :integer, default: 0
    field :file_url, :string, default: ""
    field :youtube_id, :string
    field :preview_url, :string, default: "http://example.com"
    field :price_default, :decimal, default: Decimal.new("0.00")
    field :image, :string

    field :source_provider, :string
    field :source_url, :string
    field :source_imported_at, :utc_datetime
    field :archived_at, :utc_datetime

    field :media_type, :string, default: "youtube"
    field :external_id, :string
    field :season, :integer
    field :episode_number, :integer
    field :episode_type, :string

    field :exclude_from_catalog_access, :boolean, default: false
    field :exclude_from_group_access, :boolean, default: false

    has_many :tiqit_classes, TiqitClass,
      on_replace: :delete,
      preload_order: [asc: :duration_hours, asc: :id]

    belongs_to :content_group, ContentGroup

    timestamps()
  end

  def changeset(content, attrs) do
    content
    |> cast(attrs, [
      :display_order,
      :title,
      :description,
      :date_published,
      :length,
      :preview_length,
      :file_url,
      :preview_url,
      :price_default,
      :exclude_from_catalog_access,
      :exclude_from_group_access
    ])
    |> validate_required([
      :title,
      :date_published
    ])
    |> validate_length(:title, max: 200)
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  def changeset_with_image(content, attrs) do
    content
    |> changeset(attrs)
    |> put_change(:image, attrs["image"])
  end

  @media_types ~w(youtube audio)
  @episode_types ~w(full trailer bonus)

  def media_types, do: @media_types
  def episode_types, do: @episode_types

  def audio?(%__MODULE__{media_type: "audio"}), do: true
  def audio?(_), do: false

  @doc """
  Short label for episode lists: `"Ep 3"`, `"Trailer"`, `"Bonus"`, or nil.
  """
  def episode_label(%__MODULE__{episode_type: "trailer"}), do: "Trailer"
  def episode_label(%__MODULE__{episode_type: "bonus"}), do: "Bonus"
  def episode_label(%__MODULE__{episode_number: n}) when is_integer(n), do: "Ep #{n}"
  def episode_label(_), do: nil

  @doc """
  Changeset used by the YouTube, RSS, and content pack imports. Casts
  metadata fields the manual creator form does not, including media,
  `:external_id`, episode fields, `:image`, and the `:source_*` trio.

  A youtube piece needs `:youtube_id`. An audio piece needs an https
  `:file_url`.
  """
  def import_changeset(content, attrs) do
    content
    |> cast(attrs, [
      :display_order,
      :title,
      :description,
      :date_published,
      :length,
      :image,
      :youtube_id,
      :file_url,
      :media_type,
      :external_id,
      :season,
      :episode_number,
      :episode_type,
      :source_provider,
      :source_url,
      :source_imported_at
    ])
    |> validate_required([:title, :source_provider, :media_type])
    |> validate_inclusion(:media_type, @media_types)
    |> validate_inclusion(:episode_type, @episode_types)
    |> validate_length(:title, max: 200)
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
    |> validate_media()
    |> unique_constraint(:external_id, name: :content_pieces_group_external_id_index)
  end

  defp validate_media(changeset) do
    case get_field(changeset, :media_type) do
      "youtube" ->
        validate_required(changeset, [:youtube_id])

      "audio" ->
        changeset
        |> validate_required([:file_url])
        |> validate_change(:file_url, fn :file_url, url ->
          if https_url?(url), do: [], else: [file_url: "must be an https URL"]
        end)

      _ ->
        changeset
    end
  end

  defp https_url?(url) when is_binary(url) do
    match?(%URI{scheme: "https", host: host} when is_binary(host) and host != "", URI.parse(url))
  end

  defp https_url?(_), do: false

  def default_tiqit_class(%__MODULE__{tiqit_classes: []} = _piece), do: nil

  def default_tiqit_class(%__MODULE__{} = piece) do
    piece.tiqit_classes
    |> TiqitClass.order_by_duration_hours_asc()
    |> List.first()
  end
end
