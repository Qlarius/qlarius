defmodule Qlarius.Repo.Migrations.RemoveUnusedUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :mobile_number, :text
      remove :auth_provider_id, :text
    end
  end
end
