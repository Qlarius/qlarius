defmodule Qlarius.Notifications.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_logs" do
    field :notification_type, :string
    field :channel, :string
    field :title, :string
    field :body, :string
    field :data, :map
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :failed_at, :utc_datetime
    field :failure_reason, :string

    belongs_to :user, Qlarius.Accounts.User
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:user_id, :notification_type, :channel, :title, :body, :data, :sent_at, :delivered_at, :clicked_at, :failed_at, :failure_reason])
    |> validate_required([:user_id, :notification_type, :channel, :sent_at])
  end
end
