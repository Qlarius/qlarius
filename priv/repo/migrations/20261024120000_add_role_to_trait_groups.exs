defmodule Qlarius.Repo.Migrations.AddRoleToTraitGroups do
  use Ecto.Migration

  def change do
    alter table(:trait_groups) do
      add :role, :string, null: false, default: "include"
    end

    create constraint(:trait_groups, :trait_groups_role_check,
             check: "role IN ('include', 'anti')"
           )

    create index(:trait_groups, [:role])
  end
end
