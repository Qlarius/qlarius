defmodule Qlarius.X.AdCategory do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "ad_categories" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end
end
