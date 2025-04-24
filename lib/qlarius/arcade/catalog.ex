defmodule Qlarius.Arcade.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.Creator

  schema "catalogs" do
    belongs_to :creator, Creator

    field :name, :string
    field :url, :string
    field :type, Ecto.Enum, values: ~w[site catalog collection show curriculum semester]a

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(catalog, attrs, _user_scope) do
    catalog
    |> cast(attrs, [:name, :url, :type])
    |> validate_required([:name, :url, :type])
  end
end
