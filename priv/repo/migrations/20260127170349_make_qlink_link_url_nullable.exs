defmodule Qlarius.Repo.Migrations.MakeQlinkLinkUrlNullable do
  use Ecto.Migration

  def change do
    alter table(:qlink_links) do
      modify :url, :string, null: true
    end
  end
end
