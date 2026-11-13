defmodule Qlarius.Repo.Migrations.AddTraitsParentNameIndex do
  use Ecto.Migration

  def change do
    create index(:traits, [:parent_trait_id, :trait_name],
             where: "is_active = true AND is_skipped_tag = false",
             name: :traits_parent_trait_name_active_index
           )
  end
end
