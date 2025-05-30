defmodule Qlarius.Repo.Migrations.AddIndexesToTraitValues do
  use Ecto.Migration

  def change do
    create index(:trait_values, :parent_trait_id)
    create index(:trait_values, :trait_category_id)
    create index(:traits, :trait_category_id)
    create index(:me_file_tags, [:me_file_id, :trait_id])
  end
end
