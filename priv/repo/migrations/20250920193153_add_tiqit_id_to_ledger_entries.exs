defmodule Qlarius.Repo.Migrations.AddTiqitIdToLedgerEntries do
  use Ecto.Migration

  def change do
    alter table(:ledger_entries) do
      add :tiqit_id, references(:tiqits, on_delete: :nilify_all), null: true
    end

    create index(:ledger_entries, [:tiqit_id])
  end
end
