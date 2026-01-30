defmodule Qlarius.Tiqit.Arcade.ContentGroup do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.TiqitClass

  schema "content_groups" do
    belongs_to :catalog, Catalog

    field :description, :string
    field :title, :string
    field :image, :string
    field :show_piece_thumbnails, :boolean, default: false
    field :show_piece_descriptions, :boolean, default: true

    has_many :content_pieces, ContentPiece
    has_many :tiqit_classes, TiqitClass, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description, :show_piece_thumbnails, :show_piece_descriptions])
    |> validate_required([:title])
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  @doc false
  def changeset_with_image(content_group, attrs) do
    content_group
    |> changeset(attrs)
    |> put_change(:image, attrs["image"])
  end
end
