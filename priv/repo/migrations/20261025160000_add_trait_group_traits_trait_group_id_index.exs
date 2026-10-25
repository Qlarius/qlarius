defmodule Qlarius.Repo.Migrations.AddTraitGroupTraitsTraitGroupIdIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:trait_group_traits, [:trait_group_id])
  end
end
