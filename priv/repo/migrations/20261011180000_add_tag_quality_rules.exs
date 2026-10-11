defmodule Qlarius.Repo.Migrations.AddTagQualityRules do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      add :ideal_min_tags, :integer
      add :ideal_max_tags, :integer
      add :hard_max_tags, :integer
      add :unripe_days, :integer
      add :ripen_days, :integer
      add :stale_days, :integer
      add :expired_days, :integer
    end

    create table(:trait_relationships) do
      add :trait_id, references(:traits, on_delete: :delete_all), null: false
      add :related_trait_id, references(:traits, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :note, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trait_relationships, [:trait_id, :related_trait_id, :kind],
             name: :trait_relationships_pair_kind_index
           )

    create index(:trait_relationships, [:related_trait_id])
  end
end
