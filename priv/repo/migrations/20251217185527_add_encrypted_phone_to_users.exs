defmodule Qlarius.Repo.Migrations.AddEncryptedPhoneToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :mobile_number_encrypted, :binary
      add :mobile_number_hash, :binary
      add :phone_verified_at, :utc_datetime
    end

    create unique_index(:users, [:mobile_number_hash], where: "mobile_number_hash IS NOT NULL")
  end
end
