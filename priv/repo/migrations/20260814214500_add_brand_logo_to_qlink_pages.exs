defmodule Qlarius.Repo.Migrations.AddBrandLogoToQlinkPages do
  use Ecto.Migration

  def change do
    alter table(:qlink_pages) do
      add :brand_logo, :string
    end
  end
end
