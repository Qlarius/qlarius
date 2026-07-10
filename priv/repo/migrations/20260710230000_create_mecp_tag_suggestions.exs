defmodule Qlarius.Repo.Migrations.CreateMecpTagSuggestions do
  use Ecto.Migration

  # Phase 1.5 suggestion loop: connected assistants may propose tags; nothing
  # touches the MeFile until the user answers the rendered question in the
  # Builder (ground rule 1). Grant-bound so provenance is always visible and
  # revocation can sweep; me_file_id is the effective MeFile at suggestion
  # time (proxy personas resolve naturally).
  def change do
    create table(:mecp_tag_suggestions) do
      add :mecp_grant_id, references(:mecp_grants, on_delete: :delete_all), null: false
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :trait_id, references(:traits, on_delete: :delete_all), null: false

      add :proposed_values, {:array, :text}, null: false, default: []
      add :reason, :string, size: 500
      add :status, :string, null: false, default: "pending"
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:mecp_tag_suggestions, [:me_file_id, :status])
    create index(:mecp_tag_suggestions, [:mecp_grant_id])

    # One pending suggestion per trait per MeFile, regardless of source.
    create unique_index(:mecp_tag_suggestions, [:me_file_id, :trait_id],
             where: "status = 'pending'",
             name: :mecp_tag_suggestions_pending_unique
           )
  end
end
