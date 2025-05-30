defmodule Qlarius.Tiqit.Arcade.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Creator
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.TiqitClass

  @types ~w[site catalog collection show curriculum semester]a
  @group_types ~w[show season album book class]a
  @piece_types ~w[episode chapter song piece lesson]a

  schema "catalogs" do
    belongs_to :creator, Creator
    has_many :content_groups, ContentGroup

    field :name, :string
    field :url, :string
    field :type, Ecto.Enum, values: @types
    field :group_type, Ecto.Enum, values: @group_types
    field :piece_type, Ecto.Enum, values: @piece_types

    has_many :tiqit_classes, TiqitClass, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def group_types, do: @group_types
  def piece_types, do: @piece_types

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:name, :url, :type, :group_type, :piece_type])
    |> validate_required([:name, :url, :type, :group_type, :piece_type])
    |> validate_length(:name, max: 20)
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end
end
