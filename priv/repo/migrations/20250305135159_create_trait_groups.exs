defmodule Qlarius.Repo.Migrations.CreateTraitGroups do
  use Ecto.Migration

  def change do
    create table(:trait_groups) do
      add :title, :text, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create table(:traits_trait_groups) do
      add :trait_id, references(:traits, on_delete: :delete_all), null: false
      add :trait_group_id, references(:trait_groups, on_delete: :delete_all), null: false
    end

    create index(:traits_trait_groups, :trait_id)
    create index(:traits_trait_groups, :trait_group_id)
    create unique_index(:traits_trait_groups, [:trait_id, :trait_group_id])

    create table(:target_bands_trait_groups) do
      add :target_band_id, references(:target_bands, on_delete: :delete_all), null: false
      add :trait_group_id, references(:trait_groups, on_delete: :delete_all), null: false
    end

    create index(:target_bands_trait_groups, :target_band_id)
    create index(:target_bands_trait_groups, :trait_group_id)
    create unique_index(:target_bands_trait_groups, [:target_band_id, :trait_group_id])
  end
end
