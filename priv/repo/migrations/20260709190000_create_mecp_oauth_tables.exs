defmodule Qlarius.Repo.Migrations.CreateMecpOauthTables do
  use Ecto.Migration

  # OAuth 2.1 authorization server for MCP remote connectors (build plan
  # Phase 1): dynamic client registration, PKCE authorization codes, and
  # grant-bound access/refresh token pairs. All secrets stored as SHA-256
  # hashes only.
  def change do
    create table(:mecp_oauth_clients) do
      add :client_id, :string, null: false
      add :client_name, :string
      add :redirect_uris, {:array, :text}, null: false, default: []
      add :token_endpoint_auth_method, :string, null: false, default: "none"
      add :registration_metadata, :map, null: false, default: %{}
      add :mecp_client_id, references(:mecp_clients, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mecp_oauth_clients, [:client_id])
    create index(:mecp_oauth_clients, [:mecp_client_id])

    create table(:mecp_oauth_codes) do
      add :code_hash, :string, null: false
      add :redirect_uri, :text, null: false
      add :code_challenge, :string, null: false
      add :code_challenge_method, :string, null: false, default: "S256"
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      add :mecp_oauth_client_id, references(:mecp_oauth_clients, on_delete: :delete_all),
        null: false

      add :mecp_grant_id, references(:mecp_grants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mecp_oauth_codes, [:code_hash])

    create table(:mecp_oauth_tokens) do
      add :access_token_hash, :string, null: false
      add :refresh_token_hash, :string
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime

      add :mecp_oauth_client_id, references(:mecp_oauth_clients, on_delete: :delete_all),
        null: false

      add :mecp_grant_id, references(:mecp_grants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mecp_oauth_tokens, [:access_token_hash])
    create unique_index(:mecp_oauth_tokens, [:refresh_token_hash])
    create index(:mecp_oauth_tokens, [:mecp_grant_id])
  end
end
