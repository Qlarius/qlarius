defmodule Qlarius.System.GlobalVariable do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "global_variables" do
    field :name, :string
    field :value, :string
  end

  def changeset(global_variable, attrs) do
    global_variable
    |> cast(attrs, [:name, :value])
    |> validate_required([:name])
    |> validate_length(:name, max: 64)
    |> unique_constraint(:name)
  end
end
