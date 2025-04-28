defmodule Qlarius.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "users" do
    field :username, :string
    field :email, :string, default: ""
    field :encrypted_password, :string, default: ""
    field :reset_password_token, :string
    field :reset_password_sent_at, :utc_datetime_usec
    field :remember_created_at, :utc_datetime_usec
    field :sign_in_count, :integer, default: 0
    field :current_sign_in_at, :utc_datetime_usec
    field :last_sign_in_at, :utc_datetime_usec
    field :current_sign_in_ip, :string
    field :last_sign_in_ip, :string
    field :confirmation_token, :string
    field :confirmed_at, :utc_datetime_usec
    field :confirmation_sent_at, :utc_datetime_usec
    field :unconfirmed_email, :string
    field :failed_attempts, :integer, default: 0
    field :unlock_token, :string
    field :locked_at, :utc_datetime_usec
    field :authentication_token, :string
    field :referrer_code, :string
    field :role, :string
    field :passage_id, :string
    field :mobile_number, :string

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end
end
