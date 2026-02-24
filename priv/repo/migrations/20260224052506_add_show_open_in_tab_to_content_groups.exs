defmodule Qlarius.Repo.Migrations.AddShowOpenInTabToContentGroups do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :show_open_in_tab, :boolean, default: true, null: false
    end
  end
end
