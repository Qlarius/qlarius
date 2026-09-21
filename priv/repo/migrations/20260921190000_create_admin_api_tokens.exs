defmodule Qlarius.Repo.Migrations.CreateAdminApiTokens do
  use Ecto.Migration

  def change do
    create table(:admin_api_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :label, :string, null: false
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admin_api_tokens, [:token_hash])
    create index(:admin_api_tokens, [:user_id])
  end
end
