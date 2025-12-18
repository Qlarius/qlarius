defmodule Qlarius.Repo.Migrations.RemoveUsernameFromUsers do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:users, [:username])

    alter table(:users) do
      remove :username
    end
  end
end
