defmodule Qlarius.Arcade.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.Creator
  alias Qlarius.Arcade.ContentGroup
  alias Qlarius.Arcade.TiqitClass

  @types ~w[site catalog collection show curriculum semester]a

  schema "catalogs" do
    belongs_to :creator, Creator
    has_many :content_groups, ContentGroup

    field :name, :string
    field :url, :string
    field :type, Ecto.Enum, values: @types

    has_many :tiqit_classes, TiqitClass, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:name, :url, :type])
    |> validate_required([:name, :url, :type])
    |> validate_length(:name, max: 20)
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end
end
