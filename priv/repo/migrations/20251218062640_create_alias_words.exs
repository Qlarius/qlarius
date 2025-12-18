defmodule Qlarius.Repo.Migrations.CreateAliasWords do
  use Ecto.Migration

  def change do
    create table(:alias_words) do
      add :word, :string, null: false
      add :type, :string, null: false
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:alias_words, [:type, :active])
    create unique_index(:alias_words, [:word, :type])
  end
end
