defmodule Qlarius.Repo.Migrations.AddImageToContentGroups do
  use Ecto.Migration

  def change do
    alter table(:content_groups) do
      add :image, :string
    end
  end
end
