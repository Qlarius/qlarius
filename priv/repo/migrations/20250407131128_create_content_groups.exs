defmodule Qlarius.Repo.Migrations.CreateContentGroups do
  use Ecto.Migration

  def change do
    create table(:content_groups) do
      add :title, :text
      add :description, :text
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    rename table(:content), to: table(:content_pieces)

    create table(:content_groups_content_pieces) do
      add :content_group_id, references(:content_groups, on_delete: :delete_all), null: false
      add :content_piece_id, references(:content_pieces, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:content_groups_content_pieces, [:content_group_id])
    create index(:content_groups_content_pieces, [:content_piece_id])
    create unique_index(:content_groups_content_pieces, [:content_group_id, :content_piece_id])

    rename table(:tiqit_types), :content_id, to: :content_piece_id
  end
end
