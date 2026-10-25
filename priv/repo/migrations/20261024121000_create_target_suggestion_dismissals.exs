defmodule Qlarius.Repo.Migrations.CreateTargetSuggestionDismissals do
  use Ecto.Migration

  def change do
    create table(:target_suggestion_dismissals) do
      add :target_id, references(:targets, on_delete: :delete_all), null: false
      add :parent_trait_id, references(:traits, on_delete: :delete_all), null: false
      add :dismissed_at, :utc_datetime, null: false
    end

    create unique_index(:target_suggestion_dismissals, [:target_id, :parent_trait_id])
  end
end
