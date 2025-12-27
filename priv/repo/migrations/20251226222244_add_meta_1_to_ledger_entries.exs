defmodule Qlarius.Repo.Migrations.AddMeta1ToLedgerEntries do
  use Ecto.Migration

  def change do
    alter table(:ledger_entries) do
      add :meta_1, :text
    end
  end
end
