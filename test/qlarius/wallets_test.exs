defmodule Qlarius.WalletsTest do
  use Qlarius.DataCase, async: true

  alias Qlarius.Accounts
  alias Qlarius.Repo
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Wallets
  alias Qlarius.Wallets.{LedgerEntry, LedgerEvent}

  describe "new MeFile credit allowance" do
    test "copies the default allowance and does not write a Welcome Gift" do
      %{user: user, me_file: me_file, header: header} = register_consumer!()

      assert Decimal.eq?(me_file.credit_allowance, Decimal.new("2.00"))
      assert Decimal.eq?(header.balance, Decimal.new("0.00"))

      summary = Wallets.consumer_wallet_summary(me_file)
      assert Decimal.eq?(summary.available_to_spend, Decimal.new("2.00"))
      assert Decimal.eq?(summary.available_to_tip, Decimal.new("0.25"))
      assert summary.credit_backed_tip_available?

      refute Repo.exists?(
               from e in LedgerEntry,
                 where: e.ledger_header_id == ^header.id and e.meta_1 == "Welcome Gift"
             )

      assert Decimal.eq?(Wallets.get_user_current_balance(user), Decimal.new("2.00"))
    end

    test "get_user_current_balance does not double-count credit from a poisoned preload" do
      %{user: user, me_file: me_file, header: header} = register_consumer!()

      Repo.transaction(fn ->
        Wallets.apply_credit!(header, Decimal.new("0.50"), %{
          description: "Ad",
          meta_1: "Banner Tap"
        })
      end)

      header = Repo.reload!(header)
      me_file = Repo.preload(me_file, :ledger_header)

      poisoned_header = %{
        me_file.ledger_header
        | balance: Decimal.add(header.balance, me_file.credit_allowance)
      }

      user = %{user | me_file: %{me_file | ledger_header: poisoned_header}}

      assert Decimal.eq?(header.balance, Decimal.new("0.50"))
      assert Decimal.eq?(poisoned_header.balance, Decimal.new("2.50"))
      assert Decimal.eq?(Wallets.get_user_current_balance(user), Decimal.new("2.50"))
    end
  end

  describe "authorize_and_debit_purchase/3" do
    test "purchase within allowance drives the ledger negative" do
      %{me_file: me_file} = register_consumer!()

      assert {:ok, %{header: header, entry: entry}} =
               debit!(me_file, "1.25", "Tiqit Purchase")

      assert Decimal.eq?(header.balance, Decimal.new("-1.25"))
      assert Decimal.eq?(entry.amt, Decimal.new("-1.25"))
      assert Decimal.eq?(entry.payable_delta, Decimal.new("0.00"))
      assert Decimal.eq?(Wallets.available_to_spend(reload_me_file(me_file)), Decimal.new("0.75"))
    end

    test "purchase exactly at allowance succeeds with zero available" do
      %{me_file: me_file} = register_consumer!()

      assert {:ok, %{header: header}} = debit!(me_file, "2.00", "Tiqit Purchase")
      assert Decimal.eq?(header.balance, Decimal.new("-2.00"))
      assert Decimal.eq?(Wallets.available_to_spend(reload_me_file(me_file)), Decimal.new("0.00"))
    end

    test "purchase above allowance fails without a ledger write" do
      %{me_file: me_file, header: header} = register_consumer!()

      assert {:error, :insufficient_funds} = debit!(me_file, "2.01", "Tiqit Purchase")
      header = Repo.reload!(header)
      assert Decimal.eq?(header.balance, Decimal.new("0.00"))

      assert Repo.aggregate(
               from(e in LedgerEntry, where: e.ledger_header_id == ^header.id),
               :count
             ) == 0
    end

    test "mixed-source purchase consumes non-payable then payable then credit" do
      %{me_file: me_file, header: header} = register_consumer!()

      header
      |> Ecto.Changeset.change(
        balance: Decimal.new("0.15"),
        balance_payable: Decimal.new("0.05")
      )
      |> Repo.update!()

      assert {:ok, %{header: header, entry: entry}} =
               debit!(me_file, "0.20", "Tiqit Purchase")

      assert Decimal.eq?(entry.amt, Decimal.new("-0.20"))
      assert Decimal.eq?(entry.payable_delta, Decimal.new("-0.05"))
      assert Decimal.eq?(header.balance, Decimal.new("-0.05"))
      assert Decimal.eq?(header.balance_payable, Decimal.new("0.00"))

      assert Decimal.eq?(
               Decimal.sub(header.balance, header.balance_payable),
               Decimal.new("-0.05")
             )
    end
  end

  describe "ad collect payable accounting" do
    test "payable ad after credit use can leave payable positive while activity is negative" do
      %{me_file: me_file} = register_consumer!()
      {:ok, _} = debit!(me_file, "0.50", "Tiqit Purchase")

      header = Wallets.lock_me_file_header!(me_file.id)

      %{header: header} =
        Wallets.apply_entry!(header, %{
          amt: Decimal.new("0.20"),
          payable_delta: Decimal.new("0.20"),
          description: "PAYABLE AD",
          meta_1: "Banner Tap"
        })

      assert Decimal.eq?(header.balance, Decimal.new("-0.30"))
      assert Decimal.eq?(header.balance_payable, Decimal.new("0.20"))

      summary = Wallets.consumer_wallet_summary(reload_me_file(me_file))
      assert Decimal.eq?(summary.cash_out_eligible, Decimal.new("0.00"))
      assert Decimal.eq?(summary.available_to_spend, Decimal.new("1.70"))
    end

    test "non-payable ad after credit use raises total activity only" do
      %{me_file: me_file} = register_consumer!()
      {:ok, _} = debit!(me_file, "0.50", "Tiqit Purchase")

      header = Wallets.lock_me_file_header!(me_file.id)

      %{header: header} =
        Wallets.apply_credit!(header, Decimal.new("0.20"), %{
          description: "GIFT AD",
          meta_1: "Banner Tap"
        })

      assert Decimal.eq?(header.balance, Decimal.new("-0.30"))
      assert Decimal.eq?(header.balance_payable, Decimal.new("0.00"))
    end
  end

  describe "refunds" do
    test "full reversal restores amt and payable mix" do
      %{me_file: me_file, header: header} = register_consumer!()

      header
      |> Ecto.Changeset.change(
        balance: Decimal.new("0.15"),
        balance_payable: Decimal.new("0.05")
      )
      |> Repo.update!()

      {:ok, %{entry: original}} = debit!(me_file, "0.20", "Tiqit Purchase")

      %{header: header, entry: reversal} =
        Wallets.reverse_ledger_entry!(original, %{
          description: "*REFUNDED*",
          meta_1: "Tiqit Refund"
        })

      assert reversal.reversed_ledger_entry_id == original.id
      assert Decimal.eq?(reversal.amt, Decimal.new("0.20"))
      assert Decimal.eq?(reversal.payable_delta, Decimal.new("0.05"))
      assert Decimal.eq?(header.balance, Decimal.new("0.15"))
      assert Decimal.eq?(header.balance_payable, Decimal.new("0.05"))
    end
  end

  describe "tips" do
    test "credit-backed 25 cent tip records credit_backed_amount and observes the throttle" do
      %{user: user, me_file: me_file} = register_consumer!()
      recipient = recipient_fixture!(user)

      assert {:ok, event} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)

      assert Decimal.eq?(event.credit_backed_amount, Decimal.new("0.25"))
      assert event.status == "pending"

      assert {:error, :credit_tip_throttled} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)

      assert {:ok, processed} = Wallets.process_insta_tip(event)
      assert processed.status == "completed"

      header = Wallets.get_me_file_ledger_header(me_file)
      assert Decimal.eq?(header.balance, Decimal.new("-0.25"))

      assert {:error, :credit_tip_throttled} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)
    end

    test "failed credit-backed tip does not hold the throttle" do
      %{user: user, me_file: me_file} = register_consumer!()
      recipient = recipient_fixture!(user)

      {:ok, event} =
        Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)

      {:ok, _} = debit!(me_file, "2.00", "Tiqit Purchase")
      assert {:error, :insufficient_funds} = Wallets.process_insta_tip(event)
      assert Repo.get!(LedgerEvent, event.id).status == "failed"

      Repo.transaction(fn ->
        header = Wallets.get_me_file_ledger_header(me_file)

        Wallets.apply_credit!(header, Decimal.new("2.00"), %{
          description: "Restore",
          meta_1: "Gift"
        })
      end)

      assert {:ok, _event} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)
    end

    test "ledger-funded tip does not consume the credit throttle" do
      %{user: user, me_file: me_file, header: header} = register_consumer!()
      recipient = recipient_fixture!(user)

      header
      |> Ecto.Changeset.change(balance: Decimal.new("1.00"), balance_payable: Decimal.new("0.00"))
      |> Repo.update!()

      assert {:ok, event} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.50"), user)

      assert Decimal.eq?(event.credit_backed_amount, Decimal.new("0.00"))
      assert {:ok, _} = Wallets.process_insta_tip(event)

      Wallets.get_me_file_ledger_header(me_file)
      |> Ecto.Changeset.change(balance: Decimal.new("0.00"), balance_payable: Decimal.new("0.00"))
      |> Repo.update!()

      assert {:ok, credit_tip} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.25"), user)

      assert Decimal.eq?(credit_tip.credit_backed_amount, Decimal.new("0.25"))
    end

    test "amounts above 25 cents cannot use credit" do
      %{user: user} = register_consumer!()
      recipient = recipient_fixture!(user)

      assert {:error, :credit_not_allowed} =
               Wallets.create_insta_tip_request(user, recipient, Decimal.new("0.50"), user)
    end
  end

  describe "admin credit allowance" do
    test "cannot lower allowance below existing negative ledger" do
      %{me_file: me_file} = register_consumer!()
      {:ok, _} = debit!(me_file, "1.50", "Tiqit Purchase")

      assert {:error, :below_minimum} =
               Wallets.update_credit_allowance(me_file, Decimal.new("1.00"))

      assert {:ok, updated} =
               Wallets.update_credit_allowance(reload_me_file(me_file), Decimal.new("1.50"))

      assert Decimal.eq?(updated.credit_allowance, Decimal.new("1.50"))
    end
  end

  describe "existing Welcome Gift MeFile" do
    test "historical deposit remains and allowance is additional" do
      %{me_file: me_file, header: header} = register_consumer!()

      {:ok, _entry} = Wallets.create_starter_credit(header)

      header = Repo.reload!(header)
      me_file = reload_me_file(me_file)

      assert Decimal.eq?(header.balance, Decimal.new("2.00"))
      assert Decimal.eq?(me_file.credit_allowance, Decimal.new("2.00"))

      summary = Wallets.consumer_wallet_summary(me_file)
      assert Decimal.eq?(summary.available_to_spend, Decimal.new("4.00"))
    end
  end

  describe "concurrent purchases" do
    @tag :capture_log
    test "only one purchase can consume the last available amount" do
      %{me_file: me_file} = register_consumer!()

      parent = self()

      task = fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Qlarius.Repo, parent, self())

        Repo.transaction(fn ->
          Wallets.authorize_and_debit_purchase(me_file, Decimal.new("2.00"), %{
            description: "Tiqit Purchase",
            meta_1: "Tiqit Purchase"
          })
        end)
      end

      results =
        1..2
        |> Enum.map(fn _ -> Task.async(task) end)
        |> Enum.map(&Task.await(&1, 5_000))

      oks =
        Enum.count(results, fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)

      assert oks == 1
    end
  end

  describe "rebuild_header_payable!/1" do
    test "clears cash-out that was copied from activity on non-payable collects" do
      %{me_file: me_file, header: header} = register_consumer!()

      %{header: header} =
        Repo.transaction(fn ->
          Wallets.apply_entry!(header, %{
            amt: Decimal.new("1.00"),
            payable_delta: Decimal.new("0.00"),
            description: "DEMO AD",
            meta_1: "Banner Tap"
          })
        end)
        |> then(fn {:ok, result} -> result end)

      header
      |> Ecto.Changeset.change(balance_payable: Decimal.new("1.00"))
      |> Repo.update!()

      Wallets.rebuild_header_payable!(header.id)
      header = Repo.reload!(header)
      summary = Wallets.consumer_wallet_summary(reload_me_file(me_file))

      assert Decimal.eq?(header.balance, Decimal.new("1.00"))
      assert Decimal.eq?(header.balance_payable, Decimal.new("0.00"))
      assert Decimal.eq?(summary.non_payable_balance, Decimal.new("1.00"))
      assert Decimal.eq?(summary.balance_payable, Decimal.new("0.00"))
    end
  end

  defp debit!(me_file, amount, meta) do
    Repo.transaction(fn ->
      case Wallets.authorize_and_debit_purchase(me_file, Decimal.new(amount), %{
             description: "TEST",
             meta_1: meta
           }) do
        {:ok, result} -> result
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp register_consumer! do
    {:ok, %{user: user, me_file: me_file, ledger_header: header}} =
      Accounts.register_new_user(%{
        alias: "wallet-#{System.unique_integer([:positive])}",
        date_of_birth: ~D[1990-01-01]
      })

    user = %{user | me_file: me_file}
    %{user: user, me_file: me_file, header: header}
  end

  defp reload_me_file(me_file), do: Repo.get!(Qlarius.YouData.MeFiles.MeFile, me_file.id)

  defp recipient_fixture!(user) do
    %Recipient{}
    |> Recipient.changeset(%{
      user_id: user.id,
      name: "Tip Recipient",
      site_url: "https://example.com",
      recipient_type_id: 1,
      split_code: Ecto.UUID.generate()
    })
    |> Repo.insert!()
  end
end
