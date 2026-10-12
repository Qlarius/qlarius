defmodule Qlarius.Repo.Migrations.AddConflictSeverityAndConfirmations do
  use Ecto.Migration

  def change do
    alter table(:trait_relationships) do
      add :severity, :string, null: false, default: "hard"
    end

    create table(:me_file_quality_confirmations) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :trait_relationship_id, references(:trait_relationships, on_delete: :delete_all)
      add :trait_id, references(:traits, on_delete: :delete_all)
      add :confirmed_at, :utc_datetime, null: false
    end

    create constraint(:me_file_quality_confirmations, :me_file_quality_confirmations_kind_shape,
             check: """
             (kind = 'conflict' AND trait_relationship_id IS NOT NULL AND trait_id IS NULL) OR
             (kind = 'count' AND trait_id IS NOT NULL AND trait_relationship_id IS NULL)
             """
           )

    create unique_index(:me_file_quality_confirmations, [:me_file_id, :trait_relationship_id],
             where: "kind = 'conflict'",
             name: :me_file_quality_confirmations_conflict_index
           )

    create unique_index(:me_file_quality_confirmations, [:me_file_id, :trait_id],
             where: "kind = 'count'",
             name: :me_file_quality_confirmations_count_index
           )

    create index(:me_file_quality_confirmations, [:me_file_id])
  end
end
