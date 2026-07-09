defmodule Qlarius.Repo.Migrations.AddAddSourceContextToMeFileTags do
  use Ecto.Migration

  # UX-optimization tracking only (e.g. "survey", "mefile_builder",
  # "qai_suggestion_confirmed"). Does not change authorship: the user is always
  # the author of every tag. See docs/mecp_qai_build_plan.md.
  def change do
    alter table(:me_file_tags) do
      add :add_source_context, :string
    end
  end
end
