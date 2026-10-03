defmodule Qlarius.Repo.Migrations.DropIsDemo do
  use Ecto.Migration

  def change do
    alter table(:campaigns) do
      remove :is_demo, :boolean
    end

    alter table(:offers) do
      remove :is_demo, :boolean, default: false, null: false
    end

    alter table(:ad_events) do
      remove :is_demo, :boolean
    end
  end
end
