defmodule Qlarius.Repo.Migrations.CreatePhoneVerifications do
  use Ecto.Migration

  def change do
    create table(:phone_verifications) do
      add :phone_number_hash, :binary, null: false
      add :code_hash, :binary, null: false
      add :attempts, :integer, default: 0, null: false
      add :verified, :boolean, default: false, null: false
      add :expires_at, :utc_datetime, null: false
      add :verified_at, :utc_datetime
      add :ip_address, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime)
    end

    create index(:phone_verifications, [:phone_number_hash])
    create index(:phone_verifications, [:expires_at])
  end
end
