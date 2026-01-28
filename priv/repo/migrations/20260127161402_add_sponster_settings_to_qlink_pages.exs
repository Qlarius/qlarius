defmodule Qlarius.Repo.Migrations.AddSponsterSettingsToQlinkPages do
  use Ecto.Migration

  def change do
    alter table(:qlink_pages) do
      add :recipient_id, references(:recipients, on_delete: :nilify_all)
      add :show_insta_tip, :boolean, default: false
    end

    create index(:qlink_pages, [:recipient_id])
  end
end
