defmodule Qlarius.Notifications.PushSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "push_subscriptions" do
    field :subscription_data, :map
    field :device_type, :string
    field :user_agent, :string
    field :active, :boolean, default: true
    field :last_used_at, :utc_datetime

    belongs_to :user, Qlarius.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:user_id, :subscription_data, :device_type, :user_agent, :active, :last_used_at])
    |> validate_required([:user_id, :subscription_data])
    |> validate_subscription_data()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_subscription_data(changeset) do
    case get_change(changeset, :subscription_data) do
      nil ->
        changeset

      data when is_map(data) ->
        required_keys = ["endpoint", "keys"]

        if Enum.all?(required_keys, &Map.has_key?(data, &1)) do
          changeset
        else
          add_error(changeset, :subscription_data, "must include endpoint and keys")
        end

      _ ->
        add_error(changeset, :subscription_data, "must be a map")
    end
  end
end
