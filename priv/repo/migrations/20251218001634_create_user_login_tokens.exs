defmodule Qlarius.Repo.Migrations.CreateUserLoginTokens do
  use Ecto.Migration

  def change do
    create table(:user_login_tokens) do
      add :token, :string, null: false
      add :user_id, :integer, null: false
      add :expires_at, :utc_datetime, null: false
      add :used, :boolean, default: false, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:user_login_tokens, [:token])
    create index(:user_login_tokens, [:user_id])
  end
end
