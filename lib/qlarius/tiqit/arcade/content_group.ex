defmodule Qlarius.Tiqit.Arcade.ContentGroup do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ContentPiece

  schema "content_groups" do
    belongs_to :catalog, Catalog

    field :description, :string
    field :title, :string
    field :type, Ecto.Enum, values: ~w[show season album book class]a
    field :image, QlariusWeb.Uploaders.ContentGroupImage.Type

    has_many :content_pieces, ContentPiece
    has_many :tiqit_classes, through: [:content_pieces, :tiqit_classes]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_group, attrs) do
    content_group
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end

  def image_changeset(content_group, image) do
    content_group
    |> change(%{})
    |> cast_attachments(%{image: image}, [:image])
  end
end
