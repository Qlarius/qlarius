defmodule Qlarius.Repo.Migrations.CreateReferrals do
  use Ecto.Migration

  def change do
    create table(:referrals) do
      add :referrer_type, :string, null: false
      add :referrer_id, :integer, null: false
      add :referred_me_file_id, references(:me_files, on_delete: :delete_all), null: false
      add :entered_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:referrals, [:referrer_type, :referrer_id])
    create index(:referrals, [:referred_me_file_id])
    create index(:referrals, [:status])
    create index(:referrals, [:expires_at])
  end
end
