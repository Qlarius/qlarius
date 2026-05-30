defmodule Qlarius.ContentSharingTest do
  use Qlarius.DataCase, async: true

  import Ecto.Query

  alias Qlarius.Accounts
  alias Qlarius.Accounts.Scope
  alias Qlarius.ContentSharing
  alias Qlarius.Creators
  alias Qlarius.Referrals
  alias Qlarius.Repo
  alias Qlarius.Tiqit.Arcade.{Catalog, ContentGroup, ContentPiece, TiqitClass, Tiqit}
  alias Qlarius.Wallets
  alias Qlarius.Wallets.{LedgerEntry, LedgerHeader}

  describe "starter credit" do
    test "new wallets receive the QADABRA - Welcome Gift credit" do
      user = register_user!()
      me_file = Accounts.get_me_file_by_user_id(user.id)
      header = Repo.get_by!(LedgerHeader, me_file_id: me_file.id)

      welcome =
        Repo.one(
          from e in LedgerEntry,
            where: e.ledger_header_id == ^header.id and e.meta_1 == "Welcome Gift"
        )

      assert welcome
      assert welcome.description == "QADABRA - Welcome Gift"
      assert Decimal.equal?(header.balance, welcome.amt)
      assert Decimal.compare(header.balance, Decimal.new(0)) == :gt
    end
  end

  describe "create_gift/2" do
    setup [:build_content, :build_sender]

    test "debits the sender and creates a will-call ticket", %{
      sender_scope: scope,
      group: group,
      tiqit_class: tc,
      creator: creator
    } do
      starting = wallet_balance(scope)

      assert {:ok, %{will_call: will_call, raw_token: token, raw_pin: pin}} =
               ContentSharing.create_gift(scope, %{
                 tiqit_class_id: tc.id,
                 content_group_id: group.id
               })

      sender_header = me_file_header(scope)

      debit_entry =
        Repo.get!(LedgerEntry, will_call.sender_debit_ledger_entry_id)

      assert debit_entry.description == String.upcase(creator.name)
      assert debit_entry.meta_1 == "Tiqit Gift Purchase (Will Call)"
      assert debit_entry.ledger_header_id == sender_header.id

      assert will_call.will_call_status == "at_will_call"
      assert String.length(pin) == 4
      assert String.match?(pin, ~r/^\d{4}$/)
      assert {:ok, _} = ContentSharing.get_invitation_by_token(token)

      assert Decimal.equal?(
               wallet_balance(scope),
               Decimal.sub(starting, tc.price)
             )

      reloaded_inv = Repo.get!(Qlarius.ContentSharing.ShareInvitation, will_call.share_invitation_id)
      assert reloaded_inv.sender_claim_token_encrypted
      assert reloaded_inv.sender_claim_pin_encrypted

      wc =
        Repo.preload(will_call, [
          :tiqit_class,
          :content_piece,
          :content_group,
          share_invitation: []
        ])

      message = ContentSharing.sender_gift_invitation_message(wc)
      assert message =~ pin
      assert message =~ "/tiqit/gift/#{token}"
    end

    test "rejects gifts the sender cannot afford", %{sender_scope: scope, group: group} do
      pricey =
        %TiqitClass{content_group_id: group.id}
        |> TiqitClass.changeset(%{price: Decimal.new("999.00")})
        |> Repo.insert!()

      assert {:error, :insufficient_funds} =
               ContentSharing.create_gift(scope, %{
                 tiqit_class_id: pricey.id,
                 content_group_id: group.id
               })
    end
  end

  describe "verify_claim_pin/2" do
    setup [:build_content, :build_sender, :create_gift]

    test "accepts the correct PIN", %{will_call: wc, raw_pin: pin} do
      assert {:ok, _} = ContentSharing.verify_claim_pin(wc, pin)
    end

    test "increments the attempt counter and locks after the cap", %{will_call: wc} do
      wrong = bad_pin(wc)

      wc =
        Enum.reduce(1..5, wc, fn _i, acc ->
          assert {:error, :invalid_pin} = ContentSharing.verify_claim_pin(acc, wrong)
          Repo.get!(Qlarius.ContentSharing.WillCallTiqit, acc.id)
        end)

      assert wc.claim_pin_attempt_count == 5
      assert {:error, :locked} = ContentSharing.verify_claim_pin(wc, wrong)
    end
  end

  describe "redeem_gift/2" do
    setup [:build_content, :build_sender, :create_gift, :build_recipient]

    test "runs the gift -> purchase ledger sequence and locks the tiqit", %{
      will_call: wc,
      recipient_scope: recipient_scope
    } do
      recipient_header = me_file_header(recipient_scope)
      starting = recipient_header.balance

      assert {:ok, redeemed} = ContentSharing.redeem_gift(wc, recipient_scope)
      assert redeemed.will_call_status == "picked_up"
      assert redeemed.recipient_tiqit_id

      tiqit = Repo.get!(Tiqit, redeemed.recipient_tiqit_id)
      refute is_nil(tiqit.refund_locked_at)

      entries =
        Repo.all(
          from e in LedgerEntry,
            where: e.ledger_header_id == ^recipient_header.id,
            order_by: [asc: e.id]
        )

      metas = Enum.map(entries, & &1.meta_1)
      assert "Media gift credit" in metas
      assert "Tiqit Purchase" in metas

      gift_idx = Enum.find_index(entries, &(&1.meta_1 == "Media gift credit"))
      purchase_idx = Enum.find_index(entries, &(&1.meta_1 == "Tiqit Purchase"))
      assert gift_idx < purchase_idx

      gift_entry = Enum.at(entries, gift_idx)
      purchase_entry = Enum.at(entries, purchase_idx)

      assert Decimal.equal?(gift_entry.running_balance, Decimal.add(starting, wc.amount))
      assert Decimal.equal?(purchase_entry.running_balance, starting)

      newest_first =
        Wallets.list_ledger_entries(recipient_header.id, 1, 20).entries
        |> Enum.take(2)

      assert [purchase_entry.id, gift_entry.id] == Enum.map(newest_first, & &1.id)

      # Pass-through credit + matching purchase debit net to zero.
      assert Decimal.equal?(me_file_header(recipient_scope).balance, starting)

      # FK links recorded.
      assert redeemed.recipient_gift_credit_ledger_entry_id
      assert redeemed.recipient_purchase_debit_ledger_entry_id

      # Idempotent: a second claim is rejected.
      assert {:error, :not_claimable} = ContentSharing.redeem_gift(redeemed, recipient_scope)
    end
  end

  describe "expire_unclaimed_gift/1" do
    setup [:build_content, :build_sender, :create_gift]

    test "credits the sender back and downgrades the invitation", %{
      will_call: wc,
      invitation: invitation,
      sender_scope: sender_scope,
      tiqit_class: tc
    } do
      # Force the claim window into the past.
      past = DateTime.add(DateTime.utc_now(), -1, :hour) |> DateTime.truncate(:second)

      invitation
      |> Ecto.Changeset.change(gift_expires_at: past)
      |> Repo.update!()

      before = wallet_balance(sender_scope)

      expirable_ids = Enum.map(ContentSharing.list_expirable_will_call_tiqits(), & &1.id)
      assert wc.id in expirable_ids

      assert {:ok, expired} = ContentSharing.expire_unclaimed_gift(wc)
      assert expired.will_call_status == "expired"
      refute is_nil(expired.reversed_at)

      assert Decimal.equal?(wallet_balance(sender_scope), Decimal.add(before, tc.price))
      assert Repo.get!(Qlarius.ContentSharing.ShareInvitation, invitation.id).status == "expired"
    end
  end

  describe "revoke_gift/2" do
    setup [:build_content, :build_sender, :create_gift]

    test "credits the sender and marks the gift withdrawn", %{
      will_call: wc,
      sender_scope: sender_scope,
      tiqit_class: tc
    } do
      before = wallet_balance(sender_scope)

      assert {:ok, revoked} = ContentSharing.revoke_gift(sender_scope, wc.id)
      assert revoked.will_call_status == "pulled"
      refute is_nil(revoked.reversed_at)

      assert Decimal.equal?(wallet_balance(sender_scope), Decimal.add(before, tc.price))

      assert Repo.get!(Qlarius.ContentSharing.ShareInvitation, wc.share_invitation_id).status ==
               "revoked"
    end

    test "rejects revoke after pickup", %{will_call: wc, sender_scope: sender_scope} do
      wc
      |> Ecto.Changeset.change(will_call_status: "picked_up")
      |> Repo.update!()

      assert {:error, :not_revokable} = ContentSharing.revoke_gift(sender_scope, wc.id)
    end
  end

  describe "referral attribution" do
    setup [:build_content, :build_sender]

    test "records source/source_id when a recipient registers from a gift", %{
      sender_scope: scope,
      group: group,
      tiqit_class: tc
    } do
      {:ok, %{invitation: invitation}} =
        ContentSharing.create_gift(scope, %{
          tiqit_class_id: tc.id,
          content_group_id: group.id
        })

      sender_user = scope.user
      ref_context = Referrals.Context.from_content_invitation(sender_user, :content_gift, invitation.id)

      {:ok, %{me_file: recipient_me_file}} =
        Accounts.register_new_user(
          valid_registration_attrs(),
          Referrals.Context.code(ref_context),
          source: Referrals.Context.source(ref_context),
          source_id: Referrals.Context.source_id(ref_context)
        )

      referral = Repo.get_by(Referrals.Referral, referred_me_file_id: recipient_me_file.id)
      assert referral
      assert referral.source == "content_gift"
      assert referral.source_id == invitation.id
    end
  end

  describe "share fork visits" do
    import Plug.Conn
    import Phoenix.ConnTest, only: [build_conn: 0, init_test_session: 2]

    alias Qlarius.ContentSharing.ShareInvitation

    setup [:build_content, :build_sender]

    test "canonical share link spawns a per-session fork", %{sender_scope: scope, group: group} do
      {:ok, %{raw_token: canonical_token, invitation: canonical}} =
        ContentSharing.create_share(scope, %{
          share_target_type: "content_group",
          content_group_id: group.id
        })

      conn = build_conn() |> init_test_session(%{})

      assert {:redirect, fork_token, conn} = ContentSharing.resolve_share_visit(conn, canonical_token)
      assert fork_token != canonical_token

      fork =
        Repo.get_by!(ShareInvitation, token_hash: ContentSharing.hash_token(fork_token))

      assert fork.parent_share_invitation_id == canonical.id
      assert fork.sender_user_id == canonical.sender_user_id
      assert fork.content_group_id == group.id
      assert get_session(conn, ContentSharing.share_fork_session_key(canonical.id)) == fork_token
    end

    test "same session reuses the fork without creating duplicates", %{
      sender_scope: scope,
      group: group
    } do
      {:ok, %{raw_token: canonical_token, invitation: canonical}} =
        ContentSharing.create_share(scope, %{
          share_target_type: "content_group",
          content_group_id: group.id
        })

      conn = build_conn() |> init_test_session(%{})

      assert {:redirect, fork_token, conn} = ContentSharing.resolve_share_visit(conn, canonical_token)

      assert {:ok, ^fork_token, _conn} = ContentSharing.resolve_share_visit(conn, fork_token)
      assert {:redirect, ^fork_token, _conn} = ContentSharing.resolve_share_visit(conn, canonical_token)

      fork_count =
        Repo.aggregate(
          from(i in ShareInvitation, where: i.parent_share_invitation_id == ^canonical.id),
          :count
        )

      assert fork_count == 1
    end

    test "separate sessions each get their own fork", %{sender_scope: scope, group: group} do
      {:ok, %{raw_token: canonical_token, invitation: canonical}} =
        ContentSharing.create_share(scope, %{
          share_target_type: "content_group",
          content_group_id: group.id
        })

      conn_a = build_conn() |> init_test_session(%{})
      conn_b = build_conn() |> init_test_session(%{})

      assert {:redirect, fork_a, _} = ContentSharing.resolve_share_visit(conn_a, canonical_token)
      assert {:redirect, fork_b, _} = ContentSharing.resolve_share_visit(conn_b, canonical_token)
      assert fork_a != fork_b

      fork_count =
        Repo.aggregate(
          from(i in ShareInvitation, where: i.parent_share_invitation_id == ^canonical.id),
          :count
        )

      assert fork_count == 2
    end

    test "gift links pass through without forking", %{
      sender_scope: scope,
      group: group,
      tiqit_class: tc
    } do
      {:ok, %{raw_token: gift_token}} =
        ContentSharing.create_gift(scope, %{
          tiqit_class_id: tc.id,
          content_group_id: group.id
        })

      conn = build_conn() |> init_test_session(%{})

      assert {:pass, _conn} = ContentSharing.resolve_share_visit(conn, gift_token)
    end

    test "referral signup attributes the fork invitation id", %{
      sender_scope: scope,
      group: group
    } do
      {:ok, %{raw_token: canonical_token}} =
        ContentSharing.create_share(scope, %{
          share_target_type: "content_group",
          content_group_id: group.id
        })

      conn = build_conn() |> init_test_session(%{})
      assert {:redirect, fork_token, _} = ContentSharing.resolve_share_visit(conn, canonical_token)

      fork =
        Repo.get_by!(ShareInvitation, token_hash: ContentSharing.hash_token(fork_token))

      sender_user = scope.user

      ref_context =
        Referrals.Context.from_content_invitation(sender_user, :content_share, fork.id)

      {:ok, %{me_file: recipient_me_file}} =
        Accounts.register_new_user(
          valid_registration_attrs(),
          Referrals.Context.code(ref_context),
          source: Referrals.Context.source(ref_context),
          source_id: Referrals.Context.source_id(ref_context)
        )

      referral = Repo.get_by!(Referrals.Referral, referred_me_file_id: recipient_me_file.id)
      assert referral.source == "content_share"
      assert referral.source_id == fork.id
    end
  end

  # --- fixtures ----------------------------------------------------------

  defp build_content(_ctx) do
    {:ok, creator} = Creators.create_creator(%{"name" => "Test Creator #{System.unique_integer([:positive])}"})

    catalog =
      %Catalog{creator_id: creator.id}
      |> Catalog.changeset(%{
        name: "Cat #{System.unique_integer([:positive])}",
        url: "https://example.com/#{System.unique_integer([:positive])}",
        type: :catalog,
        group_type: :show,
        piece_type: :episode
      })
      |> Repo.insert!()

    group =
      %ContentGroup{catalog_id: catalog.id}
      |> ContentGroup.changeset(%{title: "Group"})
      |> Repo.insert!()

    piece =
      %ContentPiece{content_group_id: group.id}
      |> ContentPiece.changeset(%{title: "Piece", date_published: ~D[2025-01-01]})
      |> Repo.insert!()

    tiqit_class =
      %TiqitClass{content_group_id: group.id}
      |> TiqitClass.changeset(%{price: Decimal.new("1.00")})
      |> Repo.insert!()

    %{creator: creator, catalog: catalog, group: group, piece: piece, tiqit_class: tiqit_class}
  end

  defp build_sender(_ctx) do
    user = register_user!()
    %{sender_scope: Scope.for_user(user)}
  end

  defp build_recipient(_ctx) do
    user = register_user!()
    %{recipient_scope: Scope.for_user(user)}
  end

  defp create_gift(%{sender_scope: scope, group: group, tiqit_class: tc}) do
    {:ok, %{invitation: invitation, will_call: will_call, raw_token: token, raw_pin: pin}} =
      ContentSharing.create_gift(scope, %{
        tiqit_class_id: tc.id,
        content_group_id: group.id
      })

    %{invitation: invitation, will_call: will_call, raw_token: token, raw_pin: pin}
  end

  defp register_user! do
    {:ok, %{user: user}} = Accounts.register_new_user(valid_registration_attrs())
    user
  end

  defp valid_registration_attrs do
    %{
      alias: "cs-user-#{System.unique_integer([:positive])}",
      date_of_birth: ~D[1990-01-01]
    }
  end

  defp wallet_balance(scope), do: me_file_header(scope).balance

  defp me_file_header(%Scope{user: %{me_file: me_file}}) do
    Repo.get_by!(LedgerHeader, me_file_id: me_file.id)
  end

  defp bad_pin(wc) do
    Enum.find(["0000", "1111", "2222"], "9999", fn candidate ->
      not Bcrypt.verify_pass(candidate, wc.claim_pin_hash)
    end)
  end
end
