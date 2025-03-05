defmodule Qlarius.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:media_pieces) do
      add :title, :text, null: false
      add :body_copy, :text, null: false
      add :display_url, :text, null: false
      add :jump_url, :text, null: false
      add :ad_category_id, references(:ad_categories)

      timestamps()
    end

    create index(:media_pieces, [:ad_category_id])

    create table(:media_sequences) do
      add :title, :text, null: false
      add :description, :text, null: false

      timestamps()
    end

    create table(:media_runs) do
      add :frequency, :integer, null: false
      add :frequency_buffer_hours, :integer, null: false
      add :maximum_banner_count, :integer, null: false
      add :banner_retry_buffer_hours, :integer, null: false
      add :media_piece_id, references(:media_pieces, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:media_runs, [:media_piece_id])
  end
end
