defmodule Qlarius.Repo.Migrations.AddImageSourceUrl do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :image_source_url, :text
    end

    alter table(:catalogs) do
      add :image_source_url, :text
    end

    alter table(:content_groups) do
      add :image_source_url, :text
    end

    alter table(:content_pieces) do
      add :image_source_url, :text
    end
  end
end
