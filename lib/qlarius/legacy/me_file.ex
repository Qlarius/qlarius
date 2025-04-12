defmodule Qlarius.Legacy.MeFile do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Qlarius.Legacy.{User, LedgerHeader, Referral, MeFileTag, Offer, MobilePhone}

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "me_files" do
    field :display_name, :string
    field :date_of_birth, :date
    field :sponster_token, :string
    field :split_amount, :integer, default: 50
    field :referral_code, :string

    belongs_to :user, User
    belongs_to :ledger_header, LedgerHeader
    belongs_to :referral, Referral
    has_many :me_file_tags, MeFileTag
    has_many :offers, Offer
    has_one :mobile_phone, MobilePhone

    timestamps()
  end

  def changeset(me_file, attrs) do
    me_file
    |> cast(attrs, [:display_name, :date_of_birth, :sponster_token, :split_amount, :referral_code, :user_id])
    |> validate_required([:display_name, :user_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:ledger_header_id)
    |> foreign_key_constraint(:referral_id)
  end
end
