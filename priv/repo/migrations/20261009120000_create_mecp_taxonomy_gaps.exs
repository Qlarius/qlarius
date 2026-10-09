defmodule Qlarius.Repo.Migrations.CreateMecpTaxonomyGaps do
  use Ecto.Migration

  # Taxonomy gaps: subjects assistants asked about that the trait taxonomy
  # doesn't cover (or covers only with orphaned traits), so admins can learn
  # which trait sets to add. De-identified by design:
  #
  #   * no me_file, grant or user column; `person_key` is a keyed one-way hash
  #     (HMAC with the server secret) used only to count distinct people
  #   * day granularity only (`occurred_on`, no timestamps), so rows can't be
  #     joined back to access events by time
  #   * admins see a subject only once enough different people raised it
  #     (Qlarius.MeCP.TaxonomyGaps.min_people/0)
  #
  # One row per subject, person, day and source: repeats in a day don't
  # inflate counts.
  def change do
    create table(:mecp_taxonomy_gaps) do
      add :source, :string, null: false
      add :reason, :string, null: false
      add :subject, :string, size: 160, null: false
      add :subject_key, :string, size: 160, null: false
      add :nearest_trait_id, references(:traits, on_delete: :nilify_all)
      add :proposed_values, {:array, :text}, null: false, default: []
      add :mecp_client_id, references(:mecp_clients, on_delete: :nilify_all)
      add :person_key, :string, size: 64, null: false
      add :occurred_on, :date, null: false
    end

    create index(:mecp_taxonomy_gaps, [:subject_key])
    create index(:mecp_taxonomy_gaps, [:occurred_on])
    create index(:mecp_taxonomy_gaps, [:nearest_trait_id])

    create unique_index(
             :mecp_taxonomy_gaps,
             [:subject_key, :person_key, :occurred_on, :source],
             name: :mecp_taxonomy_gaps_daily_unique
           )
  end
end
