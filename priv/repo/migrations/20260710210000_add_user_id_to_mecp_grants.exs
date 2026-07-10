defmodule Qlarius.Repo.Migrations.AddUserIdToMecpGrants do
  use Ecto.Migration

  # Grants belong to the user who approved them; the MeFile served is resolved
  # at request time (active proxy persona if one is active, else the user's
  # own). me_file_id remains as the approval-time snapshot and legacy fallback.
  def up do
    alter table(:mecp_grants) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:mecp_grants, [:user_id])

    execute """
    UPDATE mecp_grants g
    SET user_id = mf.user_id
    FROM me_files mf
    WHERE mf.id = g.me_file_id AND g.user_id IS NULL
    """
  end

  def down do
    alter table(:mecp_grants) do
      remove :user_id
    end
  end
end
