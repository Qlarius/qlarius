defmodule Qlarius.Repo.Migrations.CreatePhoneCarrierRejections do
  use Ecto.Migration

  def change do
    create table(:phone_carrier_rejections) do
      add :phone_number, :text, null: false
      add :area_code, :string
      add :line_type, :string
      add :carrier_name, :text
      add :country_code, :string
      add :mobile_country_code, :string
      add :mobile_network_code, :string
      add :rejection_reason, :string, null: false
      add :user_message, :text
      add :lookup_snapshot, :map
      add :blocked_until, :utc_datetime_usec, null: false
      add :client_ip, :string
      add :surface, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:phone_carrier_rejections, [:phone_number])
    create index(:phone_carrier_rejections, [:inserted_at])
    create index(:phone_carrier_rejections, [:area_code])
    create index(:phone_carrier_rejections, [:rejection_reason])
    create index(:phone_carrier_rejections, [:blocked_until])
    create index(:phone_carrier_rejections, [:line_type])
    create index(:phone_carrier_rejections, [:country_code])
  end
end
