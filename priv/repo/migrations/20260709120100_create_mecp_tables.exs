defmodule Qlarius.Repo.Migrations.CreateMecpTables do
  use Ecto.Migration

  # MeCP (YouData gateway) core tables. See docs/mecp_qai_build_plan.md.
  # Counterparty registry, permission grants, audit trail, and MyTerms records.
  def change do
    # Counterparty registry: Qai, BYO assistants, later commercial agents.
    create table(:mecp_clients) do
      add :name, :string, null: false
      add :client_type, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :token_hash, :string
      add :public_key, :text
      add :myterms_roster_ref, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mecp_clients, [:token_hash])
    create index(:mecp_clients, [:status])
    create index(:mecp_clients, [:client_type])

    # Permission ledger: per me_file + client, scope + disclosure tier + budget.
    create table(:mecp_grants) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :mecp_client_id, references(:mecp_clients, on_delete: :delete_all), null: false

      # scope: %{"category_ids" => [...], "trait_ids" => [...]}
      add :scope, :map, null: false, default: %{}
      # tier: 0=vault, 1=rerank, 2=oracle, 3=capsule
      add :tier, :integer, null: false, default: 0
      # budget: per-period disclosure counter config, e.g. %{"period" => "day", "max" => 50}
      add :budget, :map, null: false, default: %{}

      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:mecp_grants, [:me_file_id])
    create index(:mecp_grants, [:mecp_client_id])
    create index(:mecp_grants, [:me_file_id, :mecp_client_id])

    # MyTerms (IEEE 7012) agreement records; proffered at handshake.
    create table(:mecp_terms_agreements) do
      add :mecp_client_id, references(:mecp_clients, on_delete: :delete_all), null: false
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false

      add :roster_agreement_ref, :string
      add :agreed_at, :utc_datetime
      # agreement_record: captured snapshot of the agreed terms
      add :agreement_record, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:mecp_terms_agreements, [:mecp_client_id])
    create index(:mecp_terms_agreements, [:me_file_id])

    # Audit trail: append-only. Records shape of every external read, never raw values.
    create table(:mecp_access_events) do
      add :mecp_grant_id, references(:mecp_grants, on_delete: :delete_all), null: false

      add :kind, :string, null: false
      add :request_digest, :string
      # response_shape: jsonb summary only, e.g. %{"categories" => 3, "traits" => 12}
      add :response_shape, :map, null: false, default: %{}

      add :terms_agreement_id,
          references(:mecp_terms_agreements, on_delete: :nilify_all)

      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:mecp_access_events, [:mecp_grant_id])
    create index(:mecp_access_events, [:kind])
    create index(:mecp_access_events, [:terms_agreement_id])
  end
end
