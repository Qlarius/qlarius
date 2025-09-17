defmodule Qlarius.Repo.Migrations.AddImageToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :image, :string
    end
  end
end
