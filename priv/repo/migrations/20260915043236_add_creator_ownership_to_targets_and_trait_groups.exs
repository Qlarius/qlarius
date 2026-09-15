defmodule Qlarius.Repo.Migrations.AddCreatorOwnershipToTargetsAndTraitGroups do
  use Ecto.Migration

  # Ownership model: every `targets` and `trait_groups` row belongs to exactly
  # one org — `marketer_id` XOR `creator_id`. Audiences never cross an org
  # boundary; they are deep-copied across it.
  #
  # `marketer_id` was already nullable on both tables, so this is additive.
  # Verified before writing the CHECK: 93 targets and 223 trait_groups, none
  # with a null `marketer_id`, so every existing row satisfies it as a
  # marketer-owned asset.

  @check "(marketer_id IS NOT NULL)::int + (creator_id IS NOT NULL)::int = 1"

  def change do
    alter table(:targets) do
      add :creator_id, references(:creators, on_delete: :delete_all)
    end

    alter table(:trait_groups) do
      add :creator_id, references(:creators, on_delete: :delete_all)
    end

    create index(:targets, [:creator_id])
    create index(:trait_groups, [:creator_id])

    create constraint(:targets, :exactly_one_owner, check: @check)
    create constraint(:trait_groups, :exactly_one_owner, check: @check)
  end
end
