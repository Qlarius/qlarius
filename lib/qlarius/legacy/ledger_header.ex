defmodule Qlarius.Legacy.LedgerHeader do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at, updated_at: :updated_at]

  schema "ledger_headers" do
    field :description, :string
    field :balance, :decimal
    field :balance_payable, :decimal

    belongs_to :me_file, Qlarius.Legacy.MeFile
    belongs_to :campaign, Qlarius.Legacy.Campaign
    belongs_to :recipient, Qlarius.Legacy.Recipient
    belongs_to :marketer, Qlarius.Legacy.Marketer

    has_many :ledger_entries, Qlarius.Legacy.LedgerEntry

    timestamps()
  end

  def changeset(ledger_header, attrs) do
    ledger_header
    |> cast(attrs, [
      :description,
      :balance,
      :balance_payable,
      :me_file_id,
      :campaign_id,
      :recipient_id,
      :marketer_id
    ])
    |> validate_required([:description])
  end
end
