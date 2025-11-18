defmodule Qlarius.Repo.Migrations.AddMetaColumnsToTraits do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      add :meta_1, :string
      add :meta_2, :string
      add :meta_3, :string
    end
  end
end
