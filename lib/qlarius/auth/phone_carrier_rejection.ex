defmodule Qlarius.Auth.PhoneCarrierRejection do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "phone_carrier_rejections" do
    field :phone_number, :string
    field :area_code, :string
    field :line_type, :string
    field :carrier_name, :string
    field :country_code, :string
    field :mobile_country_code, :string
    field :mobile_network_code, :string
    field :rejection_reason, :string
    field :user_message, :string
    field :lookup_snapshot, :map
    field :blocked_until, :utc_datetime_usec
    field :client_ip, :string
    field :surface, :string

    timestamps(type: :utc_datetime_usec)
  end

  @cast_fields [
    :phone_number,
    :area_code,
    :line_type,
    :carrier_name,
    :country_code,
    :mobile_country_code,
    :mobile_network_code,
    :rejection_reason,
    :user_message,
    :lookup_snapshot,
    :blocked_until,
    :client_ip,
    :surface
  ]

  @required [:phone_number, :rejection_reason, :blocked_until]

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @cast_fields)
    |> validate_required(@required)
  end
end
