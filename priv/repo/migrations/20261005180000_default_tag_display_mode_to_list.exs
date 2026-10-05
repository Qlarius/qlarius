defmodule Qlarius.Repo.Migrations.DefaultTagDisplayModeToList do
  use Ecto.Migration

  # List becomes the MeFile default for everyone, existing rows included.
  # The view switch shipped recently, so stored values are almost all the old
  # default rather than a real choice. Down restores the column default only;
  # the previous per-row values are not recoverable.
  def up do
    alter table(:me_files) do
      modify :tag_display_mode, :string, null: false, default: "list"
    end

    execute "UPDATE me_files SET tag_display_mode = 'list' WHERE tag_display_mode <> 'list'"
  end

  def down do
    alter table(:me_files) do
      modify :tag_display_mode, :string, null: false, default: "tag"
    end
  end
end
