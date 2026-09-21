defmodule Qlarius.Repo.Migrations.TraitsMetaToText do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      modify :meta_1, :text
      modify :meta_2, :text
      modify :meta_3, :text
    end
  end
end
