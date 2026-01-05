defmodule Qlarius.Referrals.ReferralClick do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Referrals.Referral
  alias Qlarius.Sponster.AdEvent

  schema "referral_clicks" do
    belongs_to :referral, Referral
    belongs_to :ad_event, AdEvent

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(referral_click, attrs) do
    referral_click
    |> cast(attrs, [:referral_id, :ad_event_id])
    |> validate_required([:referral_id, :ad_event_id])
    |> foreign_key_constraint(:referral_id)
    |> foreign_key_constraint(:ad_event_id)
    |> unique_constraint(:ad_event_id)
  end
end
