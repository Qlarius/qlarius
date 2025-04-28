defmodule Qlarius.Accounts.MeFile do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "me_files" do
    field :display_name, :string
    field :date_of_birth, :date
    field :sponster_token, :string
    field :split_amount, :integer, default: 50
    field :referral_code, :string
    belongs_to :user, Qlarius.Accounts.User
    belongs_to :ledger_header, Qlarius.Accounts.LedgerHeader
    belongs_to :referral, Qlarius.Accounts.Referral

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end
end
