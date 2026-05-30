defmodule Qlarius.ContentSharing do
  @moduledoc """
  Content gifts and shares.

  A **gift** prepays a `TiqitClass` from the sender's wallet and leaves it at
  will call behind a 4-digit PIN; the recipient claims it on the public Tiqit
  Arqade page. A **share** is the same invitation machinery without the prepaid
  will-call layer.

  Both feed the existing referral mechanism when the recipient creates a new
  MeFile (see `Qlarius.Referrals` / `Qlarius.Accounts.register_new_user/2`).
  """
  import Ecto.Query, warn: false

  alias Qlarius.Repo
  alias Qlarius.Accounts.Scope
  alias Qlarius.Wallets
  alias Qlarius.Referrals
  alias Qlarius.System
  alias Qlarius.Tiqit.Arcade.Arcade
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.ContentSharing.{ShareInvitation, WillCallTiqit}
  alias Qlarius.Wallets.MeFileStatsBroadcaster

  @max_pin_attempts 5
  @default_claim_window_hours 48

  # --- Creation ----------------------------------------------------------

  @doc """
  Creates a will-call gift funded from the sender's wallet.

  Atomic and wallet-gated: revalidates spendable balance, debits the sender,
  and creates the `ShareInvitation` + `WillCallTiqit` with a fresh token and
  4-digit PIN. The raw token and PIN are returned ONCE (only hashes persist).

  Returns `{:ok, %{invitation, will_call, raw_token, raw_pin, claim_path}}` or
  `{:error, :insufficient_funds}`.
  """
  def create_gift(%Scope{user: %{me_file: me_file} = user}, attrs) do
    tiqit_class =
      TiqitClass
      |> Repo.get!(attrs.tiqit_class_id)
      |> Repo.preload([
        :catalog,
        content_piece: [content_group: [catalog: :creator]],
        content_group: [catalog: :creator],
        catalog: :creator
      ])

    amount = tiqit_class.price
    debit_description = will_call_gift_debit_description(tiqit_class)
    raw_token = generate_token()
    raw_pin = generate_pin()
    claim_window_hours = claim_window_hours()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      ledger_header = Wallets.get_me_file_ledger_header(me_file)

      if ledger_header == nil or
           Decimal.compare(ledger_header.balance || Decimal.new(0), amount) == :lt do
        Repo.rollback(:insufficient_funds)
      end

      ensure_referral_code!(me_file)

      debit_entry =
        Wallets.create_will_call_debit!(ledger_header, amount, debit_description)

      invitation =
        %ShareInvitation{}
        |> ShareInvitation.changeset(%{
          token_hash: hash_token(raw_token),
          share_type: "gift",
          status: "active",
          sender_user_id: user.id,
          sender_me_file_id: me_file.id,
          content_piece_id: attrs[:content_piece_id],
          content_group_id: attrs[:content_group_id],
          tiqit_class_id: tiqit_class.id,
          personal_message: attrs[:personal_message],
          claim_window_hours: claim_window_hours,
          gift_expires_at: DateTime.add(now, claim_window_hours, :hour),
          sender_claim_token_encrypted: raw_token,
          sender_claim_pin_encrypted: raw_pin
        })
        |> Repo.insert!()

      will_call =
        %WillCallTiqit{}
        |> WillCallTiqit.changeset(%{
          will_call_uuid: Ecto.UUID.generate(),
          share_invitation_id: invitation.id,
          sender_user_id: user.id,
          sender_me_file_id: me_file.id,
          tiqit_class_id: tiqit_class.id,
          content_piece_id: attrs[:content_piece_id],
          content_group_id: attrs[:content_group_id],
          amount: amount,
          claim_pin_hash: Bcrypt.hash_pwd_salt(raw_pin),
          will_call_status: "at_will_call",
          sender_debit_ledger_entry_id: debit_entry.id
        })
        |> Repo.insert!()

      %{
        invitation: invitation,
        will_call: will_call,
        raw_token: raw_token,
        raw_pin: raw_pin,
        claim_path: "/tiqit/gift/#{raw_token}"
      }
    end)
  end

  @doc """
  Creates a plain share invitation (no prepay, no will-call ticket).

  Returns `{:ok, %{invitation, raw_token, claim_path}}`.
  """
  def create_share(%Scope{user: %{me_file: me_file} = user}, attrs) do
    raw_token = generate_token()
    ensure_referral_code!(me_file)

    invitation =
      %ShareInvitation{}
      |> ShareInvitation.changeset(%{
        token_hash: hash_token(raw_token),
        share_type: "share",
        share_target_type: attrs[:share_target_type] || "content_piece",
        status: "active",
        sender_user_id: user.id,
        sender_me_file_id: me_file.id,
        content_piece_id: attrs[:content_piece_id],
        content_group_id: attrs[:content_group_id],
        personal_message: attrs[:personal_message]
      })
      |> Repo.insert!()

    {:ok,
     %{
       invitation: invitation,
       raw_token: raw_token,
       claim_path: "/tiqit/share/#{raw_token}"
     }}
  end

  # --- Resolution --------------------------------------------------------

  @doc """
  Resolves an invitation by its raw token and classifies its current state.

  Returns `{:ok, resolved}` where `resolved` includes the invitation, the
  will-call ticket (if any), a derived `:state`
  (`:active_gift | :active_share | :expired_share | :redeemed | :revoked`), and
  `:claim_time_remaining_seconds`, or `{:error, :not_found}`.
  """
  def get_invitation_by_token(raw_token) when is_binary(raw_token) do
    case Repo.get_by(ShareInvitation, token_hash: hash_token(raw_token)) do
      nil ->
        {:error, :not_found}

      invitation ->
        invitation =
          Repo.preload(invitation, [
            :will_call_tiqit,
            :content_group,
            :content_piece,
            :tiqit_class,
            :sender_me_file
          ])

        {:ok, resolve_state(invitation)}
    end
  end

  def get_invitation_by_token(_), do: {:error, :not_found}

  @doc """
  Resolves a plain share link visit to the session attribution token.

  Canonical share URLs spawn a child invitation (new token, same content) once
  per browser session so each recipient journey gets its own `source_id` for
  referrals. Gift links pass through unchanged.

  Returns:

  * `{:ok, token, conn}` — continue with this token (URL already matches)
  * `{:redirect, fork_token, conn}` — redirect to the session fork
  * `{:pass, conn}` — not a forkable share (missing, gift, inactive, etc.)
  """
  def resolve_share_visit(%Plug.Conn{} = conn, raw_token) when is_binary(raw_token) do
    conn = Plug.Conn.fetch_session(conn)

    case get_invitation_by_token(raw_token) do
      {:error, :not_found} ->
        {:pass, conn}

      {:ok, %{invitation: invitation, state: :active_share}} ->
        resolve_active_share_visit(conn, invitation, raw_token)

      {:ok, _resolved} ->
        {:pass, conn}
    end
  end

  def resolve_share_visit(conn, _), do: {:pass, conn}

  @doc "Returns the canonical (sharer-created) invitation for a share or its fork."
  def canonical_share_invitation(%ShareInvitation{share_type: "share"} = invitation) do
    case invitation.parent_share_invitation_id do
      nil ->
        invitation

      parent_id ->
        Repo.get!(ShareInvitation, parent_id)
    end
  end

  @doc """
  Creates a child share invitation for attribution tracking.

  Copies sender/content/target fields from the canonical row; only the token differs.
  """
  def fork_share_invitation!(%ShareInvitation{id: id} = canonical) when is_integer(id) do
    raw_token = generate_token()

    %ShareInvitation{}
    |> ShareInvitation.changeset(%{
      token_hash: hash_token(raw_token),
      share_type: "share",
      share_target_type: canonical.share_target_type,
      status: "active",
      sender_user_id: canonical.sender_user_id,
      sender_me_file_id: canonical.sender_me_file_id,
      content_piece_id: canonical.content_piece_id,
      content_group_id: canonical.content_group_id,
      personal_message: canonical.personal_message,
      parent_share_invitation_id: canonical.id
    })
    |> Repo.insert!()

    raw_token
  end

  @doc false
  def share_fork_session_key(canonical_id) when is_integer(canonical_id) do
    "share_fork_#{canonical_id}"
  end

  defp resolve_active_share_visit(conn, invitation, raw_token) do
    canonical = canonical_share_invitation(invitation)
    session_key = share_fork_session_key(canonical.id)
    stored_token = Plug.Conn.get_session(conn, session_key)

    target_token =
      cond do
        share_fork_for_canonical?(raw_token, canonical.id) ->
          raw_token

        share_fork_for_canonical?(stored_token, canonical.id) ->
          stored_token

        true ->
          fork_share_invitation!(canonical)
      end

    conn = Plug.Conn.put_session(conn, session_key, target_token)

    if target_token == raw_token do
      {:ok, raw_token, conn}
    else
      {:redirect, target_token, conn}
    end
  end

  defp share_fork_for_canonical?(raw_token, canonical_id)
       when is_binary(raw_token) and is_integer(canonical_id) do
    case Repo.get_by(ShareInvitation, token_hash: hash_token(raw_token)) do
      %ShareInvitation{
        share_type: "share",
        status: "active",
        parent_share_invitation_id: ^canonical_id
      } ->
        true

      _ ->
        false
    end
  end

  defp share_fork_for_canonical?(_, _), do: false

  defp resolve_state(%ShareInvitation{} = invitation) do
    now = DateTime.utc_now()
    will_call = invitation.will_call_tiqit

    state =
      cond do
        invitation.status == "revoked" -> :revoked
        invitation.status == "redeemed" -> :redeemed
        invitation.share_type == "share" -> :active_share
        gift_claimable?(invitation, will_call, now) -> :active_gift
        true -> :expired_share
      end

    remaining =
      case invitation.gift_expires_at do
        nil -> nil
        expires_at -> max(0, DateTime.diff(expires_at, now, :second))
      end

    %{
      invitation: invitation,
      will_call: will_call,
      state: state,
      claim_time_remaining_seconds: remaining
    }
  end

  defp gift_claimable?(%ShareInvitation{share_type: "gift"} = invitation, %WillCallTiqit{} = wc, now) do
    wc.will_call_status in ["at_will_call", "claim_check_required"] and
      invitation.gift_expires_at != nil and
      DateTime.compare(invitation.gift_expires_at, now) == :gt
  end

  defp gift_claimable?(_, _, _), do: false

  # --- PIN ---------------------------------------------------------------

  @doc """
  Verifies a 4-digit claim PIN against the will-call ticket.

  Returns `{:ok, will_call}`, `{:error, :invalid_pin}`, or `{:error, :locked}`
  once `#{@max_pin_attempts}` failed attempts have accumulated. Failed attempts
  increment the persisted counter.
  """
  def verify_claim_pin(%WillCallTiqit{} = will_call, pin) when is_binary(pin) do
    cond do
      will_call.claim_pin_attempt_count >= @max_pin_attempts ->
        {:error, :locked}

      Bcrypt.verify_pass(pin, will_call.claim_pin_hash) ->
        {:ok, will_call}

      true ->
        will_call
        |> Ecto.Changeset.change(claim_pin_attempt_count: will_call.claim_pin_attempt_count + 1)
        |> Repo.update!()

        {:error, :invalid_pin}
    end
  end

  # --- Redemption --------------------------------------------------------

  @doc """
  Redeems a claimable gift for the authenticated recipient.

  Atomic: credits the recipient wallet with a restricted `Media gift credit`,
  immediately runs the standard Tiqit purchase (debiting the recipient, crediting
  the creator), creates the recipient `Tiqit` with `refund_locked_at` set, stores
  all ledger FKs, and marks the gift `picked_up`. If the purchase fails the whole
  transaction rolls back and the gift stays claimable.

  Returns `{:ok, will_call}` or `{:error, reason}`.
  """
  def redeem_gift(%WillCallTiqit{} = will_call, %Scope{user: %{me_file: me_file} = user} = scope) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      locked = lock_will_call!(will_call.id)
      invitation = Repo.get!(ShareInvitation, locked.share_invitation_id)

      unless gift_claimable?(invitation, locked, DateTime.utc_now()) do
        Repo.rollback(:not_claimable)
      end

      tiqit_class = Repo.get!(TiqitClass, locked.tiqit_class_id)
      recipient_header = Wallets.get_me_file_ledger_header(me_file)

      gift_credit_entry =
        Wallets.create_gift_passthrough_credit!(recipient_header, locked.amount)

      {:ok, %{tiqit: tiqit, debit_entry: debit_entry, creator_entry: creator_entry}} =
        Arcade.purchase_tiqit_txn(scope, tiqit_class, refund_locked: true)

      locked
      |> WillCallTiqit.changeset(%{
        will_call_status: "picked_up",
        claimed_at: now,
        claimed_by_user_id: user.id,
        claimed_by_me_file_id: me_file.id,
        recipient_tiqit_id: tiqit.id,
        recipient_gift_credit_ledger_entry_id: gift_credit_entry.id,
        recipient_purchase_debit_ledger_entry_id: debit_entry.id,
        creator_credit_ledger_entry_id: creator_entry && creator_entry.id
      })
      |> Repo.update!()

      invitation
      |> ShareInvitation.changeset(%{
        status: "redeemed",
        redeemed_at: now,
        redeemed_by_user_id: user.id,
        redeemed_by_me_file_id: me_file.id
      })
      |> Repo.update!()

      Repo.get!(WillCallTiqit, locked.id)
    end)
  end

  @doc """
  Records lightweight attribution for a share redemption without granting any
  paid entitlement. Shares remain reusable; only the first redeemer is recorded.
  """
  def attach_share(%ShareInvitation{} = invitation, %Scope{user: %{me_file: me_file}}) do
    if is_nil(invitation.redeemed_by_me_file_id) do
      invitation
      |> ShareInvitation.changeset(%{redeemed_by_me_file_id: me_file.id})
      |> Repo.update()
    else
      {:ok, invitation}
    end
  end

  # --- Expiration --------------------------------------------------------

  @doc """
  Reverses an unclaimed, expired will-call gift: credits the sender back, marks
  the ticket `expired`, and downgrades the invitation to share-only (the link
  still resolves). Returns `{:ok, will_call}` or `{:error, reason}`.
  """
  def expire_unclaimed_gift(%WillCallTiqit{} = will_call) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      locked = lock_will_call!(will_call.id)

      unless locked.will_call_status == "at_will_call" do
        Repo.rollback(:not_reversible)
      end

      sender_header = Wallets.get_me_file_ledger_header_by_id(locked.sender_me_file_id)

      reversal_entry =
        Wallets.create_will_call_reversal!(sender_header, locked.amount, "Will Call Gift Reversal")

      locked
      |> WillCallTiqit.changeset(%{
        will_call_status: "expired",
        reversed_at: now,
        sender_reversal_ledger_entry_id: reversal_entry.id
      })
      |> Repo.update!()

      invitation = Repo.get!(ShareInvitation, locked.share_invitation_id)

      invitation
      |> ShareInvitation.changeset(%{status: "expired"})
      |> Repo.update!()

      Repo.get!(WillCallTiqit, locked.id)
    end)
  end

  @doc """
  Lists will-call gifts past their claim window that are still awaiting pickup,
  for the expiration worker.
  """
  def list_expirable_will_call_tiqits(now \\ DateTime.utc_now()) do
    Repo.all(
      from wc in WillCallTiqit,
        join: inv in ShareInvitation,
        on: inv.id == wc.share_invitation_id,
        where: wc.will_call_status == "at_will_call",
        where: not is_nil(inv.gift_expires_at) and inv.gift_expires_at <= ^now
    )
  end

  # --- Sender stash ------------------------------------------------------

  @sender_gift_preloads [
    :tiqit_class,
    :share_invitation,
    content_group: [catalog: :creator],
    content_piece: [content_group: [catalog: :creator]]
  ]

  @doc "Lists a sender's will-call gifts (newest first) for the /tiqits Gifted tab."
  def list_sender_gifts(%Scope{user: %{me_file: me_file}}) do
    Repo.all(
      from wc in WillCallTiqit,
        where: wc.sender_me_file_id == ^me_file.id,
        order_by: [desc: wc.inserted_at],
        preload: ^@sender_gift_preloads
    )
  end

  def list_sender_gifts(_scope), do: []

  @doc """
  Loads a sender will-call gift linked to a wallet ledger entry (debit or reversal).
  Used by `/wallet` transaction details.
  """
  def get_sender_gift_by_ledger_entry_id(entry_id) when is_integer(entry_id) do
    Repo.one(
      from wc in WillCallTiqit,
        where:
          wc.sender_debit_ledger_entry_id == ^entry_id or
            wc.sender_reversal_ledger_entry_id == ^entry_id,
        preload: ^@sender_gift_preloads
    )
  end

  @doc "Counts a sender's gifts still awaiting pickup (for the Gifted tab badge)."
  def count_pending_sender_gifts(%Scope{user: %{me_file: me_file}}) do
    Repo.one(
      from wc in WillCallTiqit,
        where: wc.sender_me_file_id == ^me_file.id,
        where: wc.will_call_status in ["at_will_call", "claim_check_required"],
        select: count(wc.id)
    )
  end

  def count_pending_sender_gifts(_scope), do: 0

  @doc """
  Builds copy-ready invitation text for a sender-owned will-call gift.
  Requires encrypted sender secrets on the invitation (gifts created after
  sender-retrieval support shipped).
  """
  def sender_gift_invitation_message(%WillCallTiqit{} = will_call) do
    will_call =
      Repo.preload(will_call, [
        :tiqit_class,
        :content_piece,
        :content_group,
        share_invitation: []
      ])

    invitation = will_call.share_invitation
    token = invitation && invitation.sender_claim_token_encrypted
    pin = invitation && invitation.sender_claim_pin_encrypted

    if is_binary(token) and token != "" and is_binary(pin) and pin != "" do
      title = gift_content_title(will_call)
      url = QlariusWeb.Endpoint.url() <> "/tiqit/gift/#{token}"

      build_gift_invitation_message(title, url, pin, invitation.gift_expires_at)
    else
      nil
    end
  end

  @doc """
  Builds copy-ready gift invitation text from title, claim URL, PIN, and deadline.
  """
  def build_gift_invitation_message(title, url, pin, gift_expires_at) do
    deadline = format_claim_deadline(gift_expires_at)

    "I bought a Tiqit for you and left it at will call:\n#{title}\n\n" <>
      "Claim it here: #{url}\n\nClaim PIN: #{pin}\n\n" <>
      "This tiqit is waiting until #{deadline}. After that, the link still works as a recommendation, but you will have to buy it yourself."
  end

  @doc """
  Revokes an unclaimed gift: credits the sender, marks will-call `pulled`,
  and sets the invitation to `revoked`.
  """
  def revoke_gift(%Scope{user: %{me_file: me_file}}, will_call_id) when is_integer(will_call_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      locked = lock_will_call!(will_call_id)

      unless locked.sender_me_file_id == me_file.id do
        Repo.rollback(:unauthorized)
      end

      unless locked.will_call_status in ["at_will_call", "claim_check_required"] do
        Repo.rollback(:not_revokable)
      end

      sender_header = Wallets.get_me_file_ledger_header(me_file)

      reversal_entry =
        Wallets.create_will_call_reversal!(sender_header, locked.amount, "Will Call Gift Reversal")

      locked
      |> WillCallTiqit.changeset(%{
        will_call_status: "pulled",
        reversed_at: now,
        sender_reversal_ledger_entry_id: reversal_entry.id
      })
      |> Repo.update!()

      invitation = Repo.get!(ShareInvitation, locked.share_invitation_id)

      invitation
      |> ShareInvitation.changeset(%{status: "revoked"})
      |> Repo.update!()

      MeFileStatsBroadcaster.broadcast_balance_updated(
        me_file.id,
        Wallets.get_me_file_ledger_header_balance(me_file)
      )

      Repo.get!(WillCallTiqit, locked.id)
    end)
  end

  @doc "Attrs for `create_gift/2` from a selected `TiqitClass` and page context."
  def gift_attrs_for_class(%TiqitClass{} = tc, piece, group) do
    base = %{tiqit_class_id: tc.id}

    cond do
      tc.content_piece_id ->
        Map.merge(base, %{content_piece_id: tc.content_piece_id, content_group_id: group.id})

      tc.content_group_id ->
        Map.merge(base, %{content_group_id: tc.content_group_id, content_piece_id: nil})

      true ->
        Map.merge(base, %{content_group_id: group.id, content_piece_id: piece && piece.id})
    end
  end

  # --- Token / PIN helpers ----------------------------------------------

  @doc "Generates a URL-safe opaque invitation token."
  def generate_token do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  @doc "SHA-256 hex digest of a raw token (what we persist)."
  def hash_token(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
  end

  defp generate_pin do
    :rand.uniform(10_000) - 1
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end

  defp claim_window_hours do
    System.get_global_variable_int("will_call_claim_window_hours", @default_claim_window_hours)
  end

  defp ensure_referral_code!(me_file) do
    case me_file.referral_code do
      code when is_binary(code) and code != "" ->
        code

      _ ->
        code = Referrals.generate_referral_code("mefile")
        {:ok, _} = Referrals.set_referral_code(me_file, code)
        code
    end
  end

  defp lock_will_call!(id) do
    Repo.one!(
      from wc in WillCallTiqit,
        where: wc.id == ^id,
        lock: "FOR UPDATE"
    )
  end

  defp gift_content_title(%WillCallTiqit{} = wc) do
    cond do
      wc.content_piece && wc.content_piece.title != "" -> wc.content_piece.title
      wc.content_group && wc.content_group.title != "" -> wc.content_group.title
      true -> "Gift"
    end
  end

  defp will_call_gift_debit_description(%TiqitClass{} = tc) do
    creator =
      cond do
        tc.content_piece && tc.content_piece.content_group ->
          tc.content_piece.content_group.catalog.creator

        tc.content_group && tc.content_group.catalog ->
          tc.content_group.catalog.creator

        tc.catalog ->
          tc.catalog.creator

        true ->
          nil
      end

    if creator, do: String.upcase(creator.name), else: "UNKNOWN"
  end

  defp format_claim_deadline(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%b %d, %Y %I:%M %p UTC")

  defp format_claim_deadline(_), do: "the claim deadline"
end
