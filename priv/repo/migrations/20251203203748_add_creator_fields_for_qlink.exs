defmodule Qlarius.Repo.Migrations.AddCreatorFieldsForQlink do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :bio, :text
      add :is_verified, :boolean, default: false
    end
  end
end
