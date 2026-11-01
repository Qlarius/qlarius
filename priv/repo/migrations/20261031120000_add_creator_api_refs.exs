defmodule Qlarius.Repo.Migrations.AddCreatorApiRefs do
  use Ecto.Migration

  @tables ~w(creators recipients catalogs content_groups content_pieces)a

  def change do
    for table <- @tables do
      alter table(table) do
        add :api_ref, :string, size: 128
      end

      create unique_index(table, [:api_ref], where: "api_ref IS NOT NULL")
    end
  end
end
