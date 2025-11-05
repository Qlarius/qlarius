defmodule Qlarius.Repo.Migrations.AddPopulationTrackingToTargets do
  use Ecto.Migration

  def change do
    alter table(:targets) do
      add :population_status, :string, default: "not_populated"
      add :last_populated_at, :naive_datetime
    end
  end
end
