defmodule Qlarius.Repo.Migrations.CreateAdCategories do
  use Ecto.Migration

  def change do
    create table(:ad_categories) do
      add :name, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
