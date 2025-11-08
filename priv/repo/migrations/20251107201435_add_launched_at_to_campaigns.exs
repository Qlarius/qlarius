defmodule Qlarius.Repo.Migrations.AddLaunchedAtToCampaigns do
  use Ecto.Migration

  def change do
    alter table(:campaigns) do
      add :launched_at, :naive_datetime
    end
  end
end
