defmodule Qlarius.Traits.Trait do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.User

  schema "traits" do
    field :name, :string

    many_to_many :users, User, join_through: "user_traits"

    timestamps(type: :utc_datetime)
  end
end
