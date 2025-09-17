defmodule Qlarius.Repo.Migrations.AddImageToCatalogs do
  use Ecto.Migration

  def change do
    alter table(:catalogs) do
      add :image, :string
    end
  end
end
