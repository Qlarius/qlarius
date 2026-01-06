defmodule Qlarius.Repo.Migrations.AddPwaFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :pwa_installed, :boolean, default: false
      add :pwa_installed_at, :utc_datetime
      add :pwa_install_dismissed_at, :utc_datetime
    end

    create index(:users, [:pwa_installed])
  end
end
