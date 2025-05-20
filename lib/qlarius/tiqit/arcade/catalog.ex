defmodule Qlarius.Tiqit.Arcade.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Tiqit.Arcade.Creator
  alias Qlarius.Tiqit.Arcade.ContentGroup

  schema "catalogs" do
    belongs_to :creator, Creator
    has_many :content_groups, ContentGroup

    field :name, :string
    field :url, :string
    field :type, Ecto.Enum, values: ~w[site catalog collection show curriculum semester]a

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:name, :url, :type])
    |> validate_required([:name, :url, :type])
    |> validate_length(:name, max: 20)
  end
end
