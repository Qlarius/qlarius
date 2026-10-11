defmodule Qlarius.Repo.Migrations.AddSkipExclusiveAndNudges do
  use Ecto.Migration

  def change do
    alter table(:traits) do
      add :is_exclusive, :boolean, null: false, default: false
      add :skip_exempt, :boolean, null: false, default: false
      add :nudge_text, :text
    end

    execute(
      "UPDATE traits SET is_exclusive = TRUE WHERE is_skipped_tag = TRUE",
      "UPDATE traits SET is_exclusive = FALSE WHERE is_skipped_tag = TRUE"
    )

    # Age, Sex (Bio), Home Zip, and Days From Birthday are required.
    # Zip parents are exempt by input type as well.
    execute(
      "UPDATE traits SET skip_exempt = TRUE WHERE id IN (93, 1, 4, 2607) OR input_type = 'single_select_zip'",
      "UPDATE traits SET skip_exempt = FALSE WHERE id IN (93, 1, 4, 2607) OR input_type = 'single_select_zip'"
    )

    create table(:me_file_trait_nudges) do
      add :me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :trait_id, references(:traits, on_delete: :delete_all), null: false
      add :shown_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:me_file_trait_nudges, [:me_file_id, :trait_id])
  end
end
