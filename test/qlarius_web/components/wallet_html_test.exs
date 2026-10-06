defmodule QlariusWeb.WalletHTMLTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Qlarius.Wallets.Summary
  alias QlariusWeb.WalletHTML

  defp summary(activity, payable, credit) do
    activity = Decimal.new(activity)
    payable = Decimal.new(payable)
    credit = Decimal.new(credit)

    %Summary{
      activity_balance: activity,
      balance_payable: payable,
      non_payable_balance: Decimal.sub(activity, payable),
      credit_allowance: credit,
      available_to_spend: Decimal.max(Decimal.add(activity, credit), Decimal.new("0.00")),
      available_to_tip: Decimal.max(activity, Decimal.new("0.00")),
      credit_backed_tip_available?: false,
      cash_out_eligible: payable
    }
  end

  defp render_card(summary, open? \\ false) do
    render_component(&WalletHTML.wallet_summary_card/1, summary: summary, details_open: open?)
  end

  describe "wallet_summary_card/1" do
    test "leads with spendable and splits the bar into in-app, cashable and credit" do
      html = render_card(summary("2.47", "1.78", "2.00"))

      assert html =~ "$4.47"
      assert html =~ "wallet-bar__seg--in_app"
      assert html =~ "wallet-bar__seg--cashable"
      assert html =~ "wallet-bar__seg--credit"
      refute html =~ "wallet-bar__seg--credit_used"
      assert html =~ "Details"
      refute html =~ "Your wallet."
    end

    test "the statement shows balances without a plus sign" do
      html = render_card(summary("2.47", "1.78", "2.00"), true)

      assert html =~ "$0.69"
      refute html =~ "+$"
      assert html =~ "Hide"
    end

    test "with activity below zero, the bar shows credit left and credit in use" do
      html = render_card(summary("-0.40", "0.00", "2.00"), true)

      assert html =~ "$1.60"
      assert html =~ "left of $2.00"
      assert html =~ "wallet-bar__seg--credit_used"
      refute html =~ "wallet-bar__seg--in_app"
      assert html =~ "−$0.40"
      assert html =~ "$0.40 in use"
    end

    test "leaves zero segments out of the bar" do
      html = render_card(summary("0.00", "0.00", "2.00"))

      refute html =~ "wallet-bar__seg--in_app"
      refute html =~ "wallet-bar__seg--cashable"
      assert html =~ "wallet-bar__seg--credit"
    end
  end

  describe "amount formatting" do
    test "signed_usd marks credits with + and debits with a true minus" do
      assert WalletHTML.signed_usd(Decimal.new("0.07")) == "+$0.07"
      assert WalletHTML.signed_usd(Decimal.new("-0.25")) == "−$0.25"
      assert WalletHTML.signed_usd(Decimal.new("0")) == "$0.00"
    end

    test "icon_tone: Tiqit lines in Tiqit colour (refunds too), other credits green" do
      line = fn amt, meta, tiqit_id ->
        %{amt: Decimal.new(amt), meta_1: meta, tiqit_id: tiqit_id}
      end

      assert WalletHTML.icon_tone(line.("-0.10", "Tiqit Purchase", nil)) == :tiqit
      assert WalletHTML.icon_tone(line.("0.10", "Tiqit Refund", nil)) == :tiqit
      assert WalletHTML.icon_tone(line.("-1.00", "Will Call Gift", nil)) == :tiqit
      assert WalletHTML.icon_tone(line.("-0.25", nil, 42)) == :tiqit
      assert WalletHTML.icon_tone(line.("0.07", "Text/Jump", nil)) == :credit
      assert WalletHTML.icon_tone(line.("-0.50", "Tip/Donation", nil)) == :neutral
    end

    test "balance_usd only marks negatives" do
      assert WalletHTML.balance_usd(Decimal.new("2.47")) == "$2.47"
      assert WalletHTML.balance_usd(Decimal.new("-0.40")) == "−$0.40"
    end
  end
end
