defmodule Qlarius.Repo.Migrations.CleanupUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove_if_exists :encrypted_password, :string
      remove_if_exists :reset_password_token, :string
      remove_if_exists :reset_password_sent_at, :naive_datetime
      remove_if_exists :remember_created_at, :naive_datetime
      remove_if_exists :confirmation_token, :string
      remove_if_exists :confirmed_at, :naive_datetime
      remove_if_exists :confirmation_sent_at, :naive_datetime
      remove_if_exists :unconfirmed_email, :string
      remove_if_exists :failed_attempts, :integer
      remove_if_exists :unlock_token, :string
      remove_if_exists :authentication_token, :string
    end

    rename table(:users), :email, to: :alias
    rename table(:users), :passage_id, to: :auth_provider_id
    rename table(:users), :created_at, to: :inserted_at

    execute "ALTER INDEX IF EXISTS index_users_on_passage_id RENAME TO index_users_on_auth_provider_id",
            "ALTER INDEX IF EXISTS index_users_on_auth_provider_id RENAME TO index_users_on_passage_id"
  end
end
