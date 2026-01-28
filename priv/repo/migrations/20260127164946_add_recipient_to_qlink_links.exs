defmodule Qlarius.Repo.Migrations.AddRecipientToQlinkLinks do
  use Ecto.Migration

  def change do
    alter table(:qlink_links) do
      add :recipient_id, references(:recipients, on_delete: :nilify_all)
    end

    create index(:qlink_links, [:recipient_id])
  end
end
