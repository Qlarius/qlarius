defmodule Qlarius.Repo.Migrations.AddHasSearchFilterToTraits do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      add :has_search_filter, :boolean, null: false, default: false
    end
  end
end
