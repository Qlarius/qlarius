defmodule Qlarius.ContentSharing.WillCallTiqit do
  @moduledoc """
  The paid "will call" layer of a gift invitation.

  Records the reversible sender debit, the 4-digit claim PIN hash, and the full
  ledger lifecycle (sender debit, recipient gift credit + purchase debit,
  creator credit, sender reversal) by foreign key. It is the reconciliation hub
  for a gift; it does not maintain its own balance.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Tiqit.Arcade.{ContentPiece, ContentGroup, TiqitClass, Tiqit}
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.ContentSharing.ShareInvitation

  @statuses ["at_will_call", "claim_check_required", "picked_up", "expired", "pulled"]

  schema "will_call_tiqits" do
    field :will_call_uuid, Ecto.UUID
    field :amount, :decimal
    field :claim_pin_hash, :string
    field :claim_pin_attempt_count, :integer, default: 0
    field :claim_pin_last_viewed_at, :utc_datetime
    field :will_call_status, :string, default: "at_will_call"
    field :claimed_at, :utc_datetime
    field :reversed_at, :utc_datetime

    belongs_to :share_invitation, ShareInvitation
    belongs_to :sender_user, User
    belongs_to :sender_me_file, MeFile
    belongs_to :tiqit_class, TiqitClass
    belongs_to :content_piece, ContentPiece
    belongs_to :content_group, ContentGroup
    belongs_to :claimed_by_user, User
    belongs_to :claimed_by_me_file, MeFile
    belongs_to :recipient_tiqit, Tiqit

    belongs_to :sender_debit_ledger_entry, LedgerEntry
    belongs_to :recipient_gift_credit_ledger_entry, LedgerEntry
    belongs_to :recipient_purchase_debit_ledger_entry, LedgerEntry
    belongs_to :creator_credit_ledger_entry, LedgerEntry
    belongs_to :sender_reversal_ledger_entry, LedgerEntry

    timestamps(type: :utc_datetime)
  end

  def changeset(will_call, attrs) do
    will_call
    |> cast(attrs, [
      :will_call_uuid,
      :amount,
      :claim_pin_hash,
      :claim_pin_attempt_count,
      :claim_pin_last_viewed_at,
      :will_call_status,
      :claimed_at,
      :reversed_at,
      :share_invitation_id,
      :sender_user_id,
      :sender_me_file_id,
      :tiqit_class_id,
      :content_piece_id,
      :content_group_id,
      :claimed_by_user_id,
      :claimed_by_me_file_id,
      :recipient_tiqit_id,
      :sender_debit_ledger_entry_id,
      :recipient_gift_credit_ledger_entry_id,
      :recipient_purchase_debit_ledger_entry_id,
      :creator_credit_ledger_entry_id,
      :sender_reversal_ledger_entry_id
    ])
    |> validate_required([
      :will_call_uuid,
      :amount,
      :claim_pin_hash,
      :will_call_status,
      :share_invitation_id,
      :sender_user_id,
      :sender_me_file_id,
      :tiqit_class_id
    ])
    |> validate_inclusion(:will_call_status, @statuses)
    |> unique_constraint(:will_call_uuid)
    |> unique_constraint(:share_invitation_id)
  end
end
