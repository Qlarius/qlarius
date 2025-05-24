defmodule Qlarius.YouData.MeFile do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "me_files" do
    field :display_name, :string
    field :date_of_birth, :date
    field :sponster_token, :string
    field :split_amount, :integer, default: 50
    field :referral_code, :string

    belongs_to :user, Qlarius.Accounts.User

    has_many :offers, Qlarius.Sponster.Offer
    has_one :ledger_header, Qlarius.Wallets.LedgerHeader

    many_to_many :trait_values, Qlarius.YouData.Traits.TraitValue,
      join_through: Qlarius.YouData.MeFileTag,
      join_keys: [me_file_id: :id, trait_id: :id]

    has_many :traits, through: [:trait_values, :trait]

    # TODO
    # belongs_to :referral, Qlarius.Accounts.Referral

    timestamps(type: :utc_datetime_usec, inserted_at_source: :created_at)
  end
end
