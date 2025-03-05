defmodule Qlarius.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration

  def change do
    create table(:campaigns) do
      add :target_id, references(:targets, on_delete: :delete_all), null: false
      add :media_sequence_id, references(:media_sequences, on_delete: :delete_all), null: false

      add :title, :text, null: false
      add :description, :text, null: false
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:campaigns, :target_id)
  end
end
