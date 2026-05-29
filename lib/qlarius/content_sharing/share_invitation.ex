defmodule Qlarius.ContentSharing.ShareInvitation do
  @moduledoc """
  A share or gift invitation link.

  A `share` recommends a content piece/group with no prepaid entitlement. A
  `gift` prepays a `TiqitClass` and leaves it at will call (see
  `Qlarius.ContentSharing.WillCallTiqit`). Only the SHA-256 `token_hash` is
  stored; the raw token lives solely in the copied link.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Accounts.User
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Tiqit.Arcade.{ContentPiece, ContentGroup, TiqitClass}
  alias Qlarius.ContentSharing.WillCallTiqit

  @share_types ["gift", "share"]
  @share_target_types ["content_piece", "content_group"]
  @statuses ["active", "expired", "redeemed", "revoked"]

  schema "share_invitations" do
    field :token_hash, :string
    field :share_type, :string
    field :share_target_type, :string
    field :status, :string, default: "active"
    field :personal_message, :string
    field :claim_window_hours, :integer, default: 48
    field :gift_expires_at, :utc_datetime
    field :converts_to_share_after_gift_expiration, :boolean, default: true
    field :redeemed_at, :utc_datetime

    belongs_to :sender_user, User
    belongs_to :sender_me_file, MeFile
    belongs_to :content_piece, ContentPiece
    belongs_to :content_group, ContentGroup
    belongs_to :tiqit_class, TiqitClass
    belongs_to :redeemed_by_user, User
    belongs_to :redeemed_by_me_file, MeFile

    has_one :will_call_tiqit, WillCallTiqit

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :token_hash,
      :share_type,
      :share_target_type,
      :status,
      :personal_message,
      :claim_window_hours,
      :gift_expires_at,
      :converts_to_share_after_gift_expiration,
      :redeemed_at,
      :sender_user_id,
      :sender_me_file_id,
      :content_piece_id,
      :content_group_id,
      :tiqit_class_id,
      :redeemed_by_user_id,
      :redeemed_by_me_file_id
    ])
    |> validate_required([:token_hash, :share_type, :sender_user_id, :sender_me_file_id])
    |> validate_inclusion(:share_type, @share_types)
    |> validate_inclusion(:share_target_type, @share_target_types)
    |> validate_inclusion(:status, @statuses)
    |> maybe_require_gift_target()
    |> unique_constraint(:token_hash)
  end

  defp maybe_require_gift_target(changeset) do
    if get_field(changeset, :share_type) == "gift" do
      validate_required(changeset, [:tiqit_class_id])
    else
      changeset
    end
  end
end
