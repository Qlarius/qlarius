defmodule Qlarius.Arcade.Creator do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Arcade.Catalog

  schema "creators" do
    field :name, :string
    has_many :catalogs, Catalog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(creator, attrs, _user_scope) do
    creator
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
