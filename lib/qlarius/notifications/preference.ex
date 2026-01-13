defmodule Qlarius.Notifications.Preference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_preferences" do
    field :channel, :string
    field :category, :string
    field :enabled, :boolean, default: true
    field :preferred_hours, {:array, :integer}, default: []
    field :quiet_hours_start, :time
    field :quiet_hours_end, :time

    belongs_to :user, Qlarius.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :channel, :category, :enabled, :preferred_hours, :quiet_hours_start, :quiet_hours_end])
    |> validate_required([:user_id, :channel, :category])
    |> validate_inclusion(:channel, ["web_push", "mobile_push", "sms"])
    |> validate_inclusion(:category, ["ad_count", "wallet", "reminders", "engagement"])
    |> validate_preferred_hours()
    |> unique_constraint([:user_id, :channel, :category])
  end

  defp validate_preferred_hours(changeset) do
    case get_change(changeset, :preferred_hours) do
      nil ->
        changeset

      hours when is_list(hours) ->
        if Enum.all?(hours, &(&1 in 0..23)) do
          changeset
        else
          add_error(changeset, :preferred_hours, "must be hours between 0 and 23")
        end

      _ ->
        add_error(changeset, :preferred_hours, "must be a list of integers")
    end
  end
end
