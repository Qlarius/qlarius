defmodule Qlarius.Referrals.Referral do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Referrals.{ReferralClick, ReferralCredit}

  @valid_referrer_types ["mefile", "creator", "recipient"]
  @valid_statuses ["active", "expired"]

  schema "referrals" do
    field :referrer_type, :string
    field :referrer_id, :integer
    field :entered_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :status, :string, default: "active"

    belongs_to :referred_me_file, MeFile
    has_many :referral_clicks, ReferralClick
    has_many :referral_credits, ReferralCredit

    timestamps(type: :utc_datetime)
  end

  def changeset(referral, attrs) do
    referral
    |> cast(attrs, [
      :referrer_type,
      :referrer_id,
      :referred_me_file_id,
      :entered_at,
      :expires_at,
      :status
    ])
    |> validate_required([
      :referrer_type,
      :referrer_id,
      :referred_me_file_id,
      :entered_at,
      :expires_at
    ])
    |> validate_inclusion(:referrer_type, @valid_referrer_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:referred_me_file_id)
    |> unique_constraint(:referred_me_file_id,
      name: :referrals_referred_me_file_id_index,
      message: "already has a referrer"
    )
  end

  def create_changeset(attrs, referred_me_file_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, 365, :day)

    %__MODULE__{}
    |> changeset(
      Map.merge(attrs, %{
        referred_me_file_id: referred_me_file_id,
        entered_at: now,
        expires_at: expires_at,
        status: "active"
      })
    )
  end
end
