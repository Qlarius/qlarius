defmodule Qlarius.Repo.Migrations.AddShowTipHeaderToQlinkLinks do
  use Ecto.Migration

  def change do
    alter table(:qlink_links) do
      add :show_tip_header, :boolean, default: true, null: false
    end
  end
end
