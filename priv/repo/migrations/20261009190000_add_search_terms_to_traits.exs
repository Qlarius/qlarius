defmodule Qlarius.Repo.Migrations.AddSearchTermsToTraits do
  use Ecto.Migration

  # Extra words that find a trait in search ("ceramics" for Pottery), on
  # parents and children alike.
  def change do
    alter table(:traits) do
      add :search_terms, {:array, :text}, null: false, default: []
    end
  end
end
