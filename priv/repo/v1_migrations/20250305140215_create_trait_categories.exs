defmodule Qlarius.Repo.Migrations.CreateTraitCategories do
  use Ecto.Migration

  def change do
    create table(:trait_categories) do
      add :name, :text, null: false
      add :display_order, :integer

      timestamps(type: :utc_datetime)
    end

    alter table(:traits) do
      add :category_id, references(:trait_categories), null: false
    end

    create index(:traits, :category_id)
  end
end
