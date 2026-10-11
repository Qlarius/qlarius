defmodule Qlarius.Repo.Migrations.AddTraitAuditEntries do
  use Ecto.Migration

  def change do
    create table(:trait_audit_entries) do
      add :token_label, :string, null: false
      add :action, :string, null: false
      add :trait_id, references(:traits, on_delete: :nilify_all)
      add :related_trait_id, references(:traits, on_delete: :nilify_all)
      add :before, :map
      add :after, :map

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:trait_audit_entries, [:trait_id])
    create index(:trait_audit_entries, [:related_trait_id])
  end
end
