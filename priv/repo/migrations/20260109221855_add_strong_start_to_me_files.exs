defmodule Qlarius.Repo.Migrations.AddStrongStartToMeFiles do
  use Ecto.Migration

  def change do
    alter table(:me_files) do
      add :strong_start_status, :string, default: "active"
      add :strong_start_completed_at, :naive_datetime
      add :strong_start_data, :map, default: "{}"
    end
  end
end
