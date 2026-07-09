defmodule Qlarius.Repo.Migrations.AddTokenHashToMecpGrants do
  use Ecto.Migration

  # MCP connector auth: a bearer token is bound to a single grant
  # (per docs/mecp_qai_build_plan.md Phase 1). Only the SHA-256 hash is stored.
  def change do
    alter table(:mecp_grants) do
      add :token_hash, :string
    end

    create unique_index(:mecp_grants, [:token_hash])
  end
end
