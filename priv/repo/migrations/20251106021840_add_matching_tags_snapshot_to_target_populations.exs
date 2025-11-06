defmodule Qlarius.Repo.Migrations.AddMatchingTagsSnapshotToTargetPopulations do
  use Ecto.Migration

  def change do
    alter table(:target_populations) do
      add :matching_tags_snapshot, :jsonb
    end

    create index(:target_populations, [:matching_tags_snapshot], using: :gin)
  end
end
