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

  @doc """
  Changeset for user_tag.
  """
  def changeset(user_tag, attrs) do
    user_tag
    |> cast(attrs, [:user_id, :trait_value_id])
    |> validate_required([:user_id, :trait_value_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:trait_value_id)
  end
end
