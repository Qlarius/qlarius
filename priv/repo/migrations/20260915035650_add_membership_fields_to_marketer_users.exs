defmodule Qlarius.Repo.Migrations.AddMembershipFieldsToMarketerUsers do
  use Ecto.Migration

  # Brings `marketer_users` to parity with `creator_memberships`. The table
  # arrived in the Rails import as a bare join with no role, no constraints
  # and no indexes, and nothing in the application ever wrote to it, so it is
  # empty — the tightening below is safe without a backfill.

  def up do
    # Postgres backfills existing rows from the default, so no separate UPDATE.
    alter table(:marketer_users) do
      add :role, :string, null: false, default: "owner"
      add :invited_by_id, :bigint
      add :accepted_at, :utc_datetime
    end

    # Memberships with a null side are meaningless; the legacy table allowed
    # both. Reverse is a no-op — the rows are gone and cannot be reconstructed.
    execute(
      "DELETE FROM marketer_users WHERE user_id IS NULL OR marketer_id IS NULL",
      ""
    )

    alter table(:marketer_users) do
      modify :user_id, references(:users, on_delete: :delete_all), null: false
      modify :marketer_id, references(:marketers, on_delete: :delete_all), null: false
    end

    create index(:marketer_users, [:user_id])
    create index(:marketer_users, [:marketer_id])
    create unique_index(:marketer_users, [:user_id, :marketer_id])
  end

  def down do
    drop unique_index(:marketer_users, [:user_id, :marketer_id])
    drop index(:marketer_users, [:marketer_id])
    drop index(:marketer_users, [:user_id])

    drop constraint(:marketer_users, "marketer_users_user_id_fkey")
    drop constraint(:marketer_users, "marketer_users_marketer_id_fkey")

    alter table(:marketer_users) do
      modify :user_id, :bigint, null: true
      modify :marketer_id, :bigint, null: true
      remove :accepted_at
      remove :invited_by_id
      remove :role
    end
  end
end
