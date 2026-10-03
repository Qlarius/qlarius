defmodule Qlarius.Sponster.Campaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.Campaigns.{MediaSequence, Target, Bid}
  alias Qlarius.Wallets.LedgerHeader

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime, inserted_at: :created_at]

  schema "campaigns" do
    field :title, :string
    field :description, :string
    field :start_date, :naive_datetime
    field :end_date, :naive_datetime
    field :is_payable, :boolean
    field :is_throttled, :boolean
    field :is_ptp, :boolean, default: false
    field :api_ref, :string
    field :launched_at, :naive_datetime
    field :deactivated_at, :naive_datetime

    belongs_to :marketer, Marketer
    belongs_to :target, Target
    belongs_to :media_sequence, MediaSequence

    has_many :bids, Bid
    has_one :ledger_header, LedgerHeader

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :description,
      :start_date,
      :end_date,
      :is_payable,
      :is_throttled,
      :is_ptp,
      :api_ref,
      :launched_at,
      :deactivated_at
    ])
    |> validate_required([
      :marketer_id,
      :target_id,
      :media_sequence_id,
      :title,
      :start_date
    ])
    |> apply_ptp_defaults(attrs)
    |> Qlarius.ApiRef.validate()
  end

  # PTP campaigns are Qadabra funded and spaced out by the global throttle, so
  # a new one defaults to non-payable and throttled unless the caller says otherwise.
  defp apply_ptp_defaults(%{data: %{id: nil}} = changeset, attrs) do
    if get_field(changeset, :is_ptp) do
      changeset
      |> default_unless_given(attrs, :is_payable, false)
      |> default_unless_given(attrs, :is_throttled, true)
    else
      changeset
    end
  end

  defp apply_ptp_defaults(changeset, _attrs), do: changeset

  defp default_unless_given(changeset, attrs, key, value) do
    if Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key)) do
      changeset
    else
      put_change(changeset, key, value)
    end
  end
end
