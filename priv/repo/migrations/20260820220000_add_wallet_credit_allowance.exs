defmodule Qlarius.Repo.Migrations.AddWalletCreditAllowance do
  use Ecto.Migration

  def change do
    alter table(:me_files) do
      add :credit_allowance, :decimal, precision: 10, scale: 2, null: false, default: "0.00"
    end

    alter table(:ledger_entries) do
      add :payable_delta, :decimal, precision: 10, scale: 2

      add :reversed_ledger_entry_id,
          references(:ledger_entries, on_delete: :nilify_all)
    end

    alter table(:ledger_events) do
      add :credit_backed_amount, :decimal,
        precision: 10,
        scale: 2,
        null: false,
        default: "0.00"
    end

    create index(:ledger_entries, [:reversed_ledger_entry_id])

    execute(
      "UPDATE me_files SET credit_allowance = 2.00",
      "UPDATE me_files SET credit_allowance = 0.00"
    )

    execute(
      """
      INSERT INTO global_variables (name, value)
      SELECT 'default_credit_allowance', '2.00'
      WHERE NOT EXISTS (
        SELECT 1 FROM global_variables WHERE name = 'default_credit_allowance'
      )
      """,
      "DELETE FROM global_variables WHERE name = 'default_credit_allowance'"
    )
  end
end
