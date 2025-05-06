defmodule Qlarius.Accounts.MarketerUser do
  use Ecto.Schema

  schema "marketer_users" do
    belongs_to :user, Qlarius.Accounts.User
    belongs_to :marketer, Qlarius.Accounts.Marketer

    timestamps(type: :utc_datetime, inserted_at_source: :created_at)
  end
end
