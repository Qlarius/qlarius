defmodule Qlarius.Repo.Migrations.AddCreatorIdToLedgerHeaders do
  use Ecto.Migration

  def change do
    alter table(:ledger_headers) do
      add :creator_id, references(:creators, on_delete: :nothing), null: true
    end

    create index(:ledger_headers, [:creator_id])
  end
end
