defmodule Qlarius.Repo.Migrations.CreateCreatorMemberships do
  use Ecto.Migration

  def change do
    create table(:creator_memberships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :creator_id, references(:creators, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "owner"
      add :invited_by_id, :bigint
      add :accepted_at, :utc_datetime

      timestamps()
    end

    create index(:creator_memberships, [:user_id])
    create index(:creator_memberships, [:creator_id])
    create unique_index(:creator_memberships, [:user_id, :creator_id])
  end
end
