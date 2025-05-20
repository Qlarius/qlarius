defmodule Qlarius.Repo.Migrations.TiqitClassDurationMustBeUnique do
  use Ecto.Migration

  def change do
    create unique_index(:tiqit_classes, [:duration_hours, :catalog_id])
    create unique_index(:tiqit_classes, [:duration_hours, :content_group_id])
    create unique_index(:tiqit_classes, [:duration_hours, :content_piece_id])
  end
end
