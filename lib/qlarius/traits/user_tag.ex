defmodule Qlarius.Traits.UserTag do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  alias Qlarius.Accounts.User
  alias Qlarius.Traits.TraitValue

  schema "user_trait_values" do
    belongs_to :user, User
    belongs_to :trait_value, TraitValue

    timestamps(type: :utc_datetime)
  end
end
