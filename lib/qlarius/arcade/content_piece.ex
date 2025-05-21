defmodule Qlarius.Arcade.ContentPiece do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.TiqitClass

  schema "content_pieces" do
    field :title, :string
    field :description, :string
    field :date_published, :date
    field :length, :integer, default: 0
    field :preview_length, :integer, default: 0
    field :file_url, :string, default: ""
    field :youtube_id, :string
    field :preview_url, :string, default: "http://example.com"
    field :price_default, :decimal, default: Decimal.new("0.00")

    has_many :tiqit_classes, TiqitClass, on_replace: :delete
    belongs_to :content_group, ContentGroup

    timestamps()
  end

  def changeset(content, attrs) do
    content
    |> cast(attrs, [
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
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  def default_tiqit_class(%__MODULE__{} = piece) do
    Enum.min_by(piece.tiqit_classes, & &1.duration_hours)
  end
end
