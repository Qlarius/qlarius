defmodule Qlarius.Arcade.ContentGroup do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  alias Qlarius.Arcade.Catalog
  alias Qlarius.Arcade.ContentPiece
  alias Qlarius.Arcade.TiqitClass

  schema "content_groups" do
    belongs_to :catalog, Catalog

    field :description, :string
    field :title, :string
    field :image, QlariusWeb.Uploaders.ContentGroupImage.Type

    has_many :content_pieces, ContentPiece
    has_many :tiqit_classes, TiqitClass, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  def image_changeset(content_group, image) do
    content_group
    |> change(%{})
    |> cast_attachments(%{image: image}, [:image])
  end
end
