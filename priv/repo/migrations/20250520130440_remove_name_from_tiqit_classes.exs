defmodule Qlarius.Repo.Migrations.RemoveNameFromTiqitClasses do
  use Ecto.Migration

  def change do
    alter table(:tiqit_classes) do
      remove :name, :string
    end
  end
end
