defmodule Qlarius.Repo.Migrations.AddSourceToReferrals do
  use Ecto.Migration

  def change do
    alter table(:referrals) do
      add :source, :string
      add :source_id, :bigint
    end

    create index(:referrals, [:source])
    create index(:referrals, [:source, :source_id])
  end
end
