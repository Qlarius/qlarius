defmodule Qlarius.Repo.Migrations.CreateUserDevices do
  use Ecto.Migration

  def change do
    create table(:user_devices) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :bigint, null: false, default: 0
      add :device_name, :string
      add :device_type, :string
      add :last_used_at, :utc_datetime
      add :trusted, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_devices, [:credential_id])
    create index(:user_devices, [:user_id])
  end
end
