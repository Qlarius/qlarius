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
      :price_default
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

  @doc """
  Changeset used by the YouTube import flow. Casts metadata fields the
  manual creator form does not, including `:youtube_id`, `:image`, and
  the `:source_*` provenance trio.
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
      :source_provider,
      :source_url,
      :source_imported_at
    ])
    |> validate_required([:title, :youtube_id, :source_provider])
    |> validate_length(:title, max: 200)
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
  end

  def default_tiqit_class(%__MODULE__{tiqit_classes: []} = _piece), do: nil

  def default_tiqit_class(%__MODULE__{} = piece) do
    Enum.min_by(piece.tiqit_classes, & &1.duration_hours)
  end
end
