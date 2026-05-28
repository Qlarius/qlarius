defmodule Qlarius.Repo.Migrations.AddRecipientIdToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :recipient_id, references(:recipients, on_delete: :nilify_all)
    end

    create index(:creators, [:recipient_id])
  end
end
