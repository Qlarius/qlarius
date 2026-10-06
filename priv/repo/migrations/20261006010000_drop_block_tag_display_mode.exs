defmodule Qlarius.Repo.Migrations.DropBlockTagDisplayMode do
  use Ecto.Migration

  def up do
    execute "UPDATE me_files SET tag_display_mode = 'list' WHERE tag_display_mode = 'block'"
  end

  def down do
    :ok
  end
end
