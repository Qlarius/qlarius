defmodule Qlarius.Repo.Migrations.AddBrandLogoMaxWidthToQlinkPages do
  use Ecto.Migration

  def change do
    alter table(:qlink_pages) do
      add :brand_logo_max_width, :integer, default: 460, null: false
    end
  end
end
