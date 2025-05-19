defmodule Qlarius.Repo.Migrations.CreateLedgerHeadersAndEntries do
  use Ecto.Migration

  def change do
    create table(:ledger_headers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :description, :text, null: false
      add :balance, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create index(:ledger_headers, :user_id)

    create table(:ledger_entries) do
      add :amount, :decimal, precision: 8, scale: 2, null: false
      add :description, :text, null: false
      add :ledger_header_id, references(:ledger_headers, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:ledger_entries, :ledger_header_id)
  end
end
