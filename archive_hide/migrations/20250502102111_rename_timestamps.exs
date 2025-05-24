defmodule Qlarius.Repo.Migrations.RenameTimestamps do
  use Ecto.Migration

  def change do
    rename table(:surveys), :created_by, to: :created_by_id
    rename table(:surveys), :updated_by, to: :updated_by_id

    rename table(:survey_categories), :added_by, to: :added_by_id
    rename table(:survey_categories), :modified_by, to: :modified_by_id
  end
end
