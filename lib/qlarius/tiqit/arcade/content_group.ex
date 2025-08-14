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
    # Process.get() is there to avoid a type warning that comes from the
    # waffle_ecto package. it's a known issue with the Elixir type system that
    # should resolved in the future. but for now I'm tired of the noise
    content_group
    |> change(%{})
    |> cast_attachments(Process.get(:unused_key, %{image: image}), [:image])
  end
end
