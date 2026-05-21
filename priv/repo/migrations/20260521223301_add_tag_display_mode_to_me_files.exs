defmodule Qlarius.Repo.Migrations.AddTagDisplayModeToMeFiles do
  use Ecto.Migration

  def change do
    alter table(:me_files) do
      add :tag_display_mode, :string, null: false, default: "tag"
    end
  end
end
