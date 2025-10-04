defmodule Qlarius.Repo.Migrations.CreateLedgerEvents do
  use Ecto.Migration

  def change do
    create table(:ledger_events) do
      add :from_ledger_id, references(:ledger_headers, on_delete: :restrict), null: false
      add :to_ledger_id, references(:ledger_headers, on_delete: :restrict), null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :requested_by_user_id, references(:users, on_delete: :restrict), null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create index(:ledger_events, [:from_ledger_id])
    create index(:ledger_events, [:to_ledger_id])
    create index(:ledger_events, [:requested_by_user_id])
    create index(:ledger_events, [:status])
    create index(:ledger_events, [:inserted_at])
  end
end
