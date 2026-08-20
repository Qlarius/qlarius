defmodule Qlarius.Wallets.Consumer do
  @moduledoc false

  import Ecto.Query

  alias Qlarius.Repo
  alias Qlarius.Wallets.{LedgerEntry, LedgerEvent, LedgerHeader, Summary}
  alias Qlarius.YouData.MeFiles.MeFile

  @zero Decimal.new("0.00")
  @default_credit_allowance "2.00"
  @credit_backed_tip_amount "0.25"

  def zero, do: @zero

  def default_credit_allowance do
    Qlarius.System.get_global_variable("default_credit_allowance", @default_credit_allowance)
    |> Decimal.new()
  end

  def credit_backed_tip_amount, do: Decimal.new(@credit_backed_tip_amount)

  def consumer_wallet_summary(%MeFile{} = me_file) do
    header = ledger_header_for(me_file)
    allowance = me_file.credit_allowance || @zero
    build_summary(header, allowance)
  end

  def consumer_wallet_summary(nil), do: empty_summary()

  def available_to_spend(%MeFile{} = me_file) do
    consumer_wallet_summary(me_file).available_to_spend
  end

  def lock_me_file_header!(me_file_id) do
    Repo.one!(
      from h in LedgerHeader,
        where: h.me_file_id == ^me_file_id,
        lock: "FOR UPDATE"
    )
  end

  def lock_header!(header_id) do
    Repo.one!(
      from h in LedgerHeader,
        where: h.id == ^header_id,
        lock: "FOR UPDATE"
    )
  end

  def allocate_debit(%LedgerHeader{} = header, allowance, amount) do
    amount = to_dec(amount)
    allowance = to_dec(allowance)

    cond do
      Decimal.compare(amount, @zero) == :lt ->
        {:error, :invalid_amount}

      Decimal.compare(amount, @zero) != :gt ->
        {:ok, %{amt: @zero, payable_delta: @zero, credit_amount: @zero}}

      true ->
        activity = header.balance || @zero
        spendable = Decimal.add(activity, allowance)

        if Decimal.compare(amount, spendable) == :gt do
          {:error, :insufficient_funds}
        else
          payable = header.balance_payable || @zero
          non_payable = Decimal.sub(activity, payable)
          from_non_payable = Decimal.min(amount, positive_part(non_payable))
          remain = Decimal.sub(amount, from_non_payable)
          from_payable = Decimal.min(remain, positive_part(payable))
          credit_amount = Decimal.sub(remain, from_payable)

          {:ok,
           %{
             amt: Decimal.negate(amount),
             payable_delta: Decimal.negate(from_payable),
             credit_amount: credit_amount
           }}
        end
    end
  end

  def authorize_and_debit_purchase(%MeFile{} = me_file, amount, attrs)
      when is_map(attrs) do
    header = lock_me_file_header!(me_file.id)
    me_file = Repo.get!(MeFile, me_file.id)
    amount = to_dec(amount)

    case allocate_debit(header, me_file.credit_allowance || @zero, amount) do
      {:ok, alloc} ->
        {:ok,
         apply_entry!(
           header,
           Map.merge(attrs, %{amt: alloc.amt, payable_delta: alloc.payable_delta})
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def apply_credit!(%LedgerHeader{} = header, amount, attrs, opts \\ []) do
    header = lock_header!(header.id)
    amount = to_dec(amount)
    payable? = Keyword.get(opts, :payable, false)
    payable_delta = if payable?, do: amount, else: @zero

    apply_entry!(
      header,
      Map.merge(attrs, %{amt: amount, payable_delta: payable_delta})
    )
  end

  def reverse_ledger_entry!(%LedgerEntry{} = original, attrs) when is_map(attrs) do
    header = lock_header!(original.ledger_header_id)
    orig_pd = original.payable_delta || @zero

    apply_entry!(
      header,
      Map.merge(attrs, %{
        amt: Decimal.negate(original.amt),
        payable_delta: Decimal.negate(orig_pd),
        reversed_ledger_entry_id: original.id
      })
    )
  end

  def apply_entry!(%LedgerHeader{} = header, attrs) when is_map(attrs) do
    amt = Map.fetch!(atomize_keys(attrs), :amt)
    payable_delta = Map.get(atomize_keys(attrs), :payable_delta) || @zero
    new_balance = Decimal.add(header.balance || @zero, amt)
    new_payable = Decimal.add(header.balance_payable || @zero, payable_delta)

    entry_attrs =
      attrs
      |> atomize_keys()
      |> Map.merge(%{
        ledger_header_id: header.id,
        amt: amt,
        payable_delta: payable_delta,
        running_balance: new_balance
      })

    entry =
      %LedgerEntry{}
      |> LedgerEntry.changeset(entry_attrs)
      |> Repo.insert!()

    header =
      header
      |> Ecto.Changeset.change(balance: new_balance, balance_payable: new_payable)
      |> Repo.update!()

    %{header: header, entry: entry}
  end

  def tip_quote(%MeFile{} = me_file, amount) do
    header = ledger_header_for(me_file)
    do_tip_quote(header, me_file.credit_allowance || @zero, amount, exclude_event_id: nil)
  end

  def authorize_tip(%MeFile{} = me_file, amount, opts \\ []) do
    header = lock_me_file_header!(me_file.id)
    me_file = Repo.get!(MeFile, me_file.id)
    exclude_event_id = Keyword.get(opts, :exclude_event_id)

    do_tip_quote(header, me_file.credit_allowance || @zero, amount,
      exclude_event_id: exclude_event_id
    )
    |> Map.put(:header, header)
    |> Map.put(:me_file, me_file)
  end

  def credit_backed_tip_throttle_active?(header_id, opts \\ []) do
    cutoff = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
    exclude_event_id = Keyword.get(opts, :exclude_event_id)

    query =
      from e in LedgerEvent,
        where: e.from_ledger_id == ^header_id,
        where: e.status in ["pending", "processing", "completed"],
        where: e.credit_backed_amount > 0,
        where: e.inserted_at > ^cutoff

    query =
      if exclude_event_id do
        from e in query, where: e.id != ^exclude_event_id
      else
        query
      end

    Repo.exists?(query)
  end

  def tip_notice_copy(%{authorized?: true, credit_backed_amount: amount}) do
    if Decimal.compare(amount, @zero) == :gt do
      "This 25¢ tip uses your credit allowance. Credit-backed tips are limited to one every 24 hours."
    end
  end

  def tip_notice_copy(%{authorized?: false, reason: :credit_tip_throttled}) do
    "You've already used a credit-backed tip in the last 24 hours. This amount needs earned wallet funds."
  end

  def tip_notice_copy(%{authorized?: false, reason: :credit_not_allowed}) do
    "Credit can only cover a 25¢ tip, once every 24 hours. This amount needs earned wallet funds."
  end

  def tip_notice_copy(%{authorized?: false, reason: :insufficient_funds}) do
    "Not enough available to send this tip."
  end

  def tip_notice_copy(_), do: nil

  def update_credit_allowance(%MeFile{} = me_file, new_amount) do
    new_amount = to_dec(new_amount)
    header = ledger_header_for(me_file)
    activity = (header && header.balance) || @zero
    min_allowance = Decimal.max(@zero, Decimal.negate(Decimal.min(activity, @zero)))

    cond do
      Decimal.compare(new_amount, @zero) == :lt ->
        {:error, :below_minimum}

      Decimal.compare(new_amount, min_allowance) == :lt ->
        {:error, :below_minimum}

      true ->
        me_file
        |> MeFile.changeset(%{credit_allowance: new_amount})
        |> Repo.update()
    end
  end

  defp do_tip_quote(nil, _allowance, _amount, _opts) do
    %{authorized?: false, reason: :insufficient_funds, credit_backed_amount: @zero}
  end

  defp do_tip_quote(%LedgerHeader{} = header, allowance, amount, opts) do
    amount = to_dec(amount)

    case allocate_debit(header, allowance, amount) do
      {:error, reason} ->
        %{authorized?: false, reason: reason, credit_backed_amount: @zero}

      {:ok, alloc} ->
        cond do
          Decimal.compare(alloc.credit_amount, @zero) == :gt and
              not Decimal.eq?(amount, credit_backed_tip_amount()) ->
            %{
              authorized?: false,
              reason: :credit_not_allowed,
              credit_backed_amount: alloc.credit_amount
            }

          Decimal.compare(alloc.credit_amount, @zero) == :gt and
              credit_backed_tip_throttle_active?(header.id, opts) ->
            %{
              authorized?: false,
              reason: :credit_tip_throttled,
              credit_backed_amount: alloc.credit_amount
            }

          true ->
            %{
              authorized?: true,
              reason: nil,
              credit_backed_amount: alloc.credit_amount,
              payable_delta: alloc.payable_delta,
              amt: alloc.amt
            }
        end
    end
  end

  defp build_summary(nil, allowance) do
    %Summary{
      activity_balance: @zero,
      balance_payable: @zero,
      non_payable_balance: @zero,
      credit_allowance: allowance || @zero,
      available_to_spend: positive_part(allowance || @zero),
      available_to_tip: @zero,
      credit_backed_tip_available?: false,
      cash_out_eligible: @zero
    }
  end

  defp build_summary(%LedgerHeader{} = header, allowance) do
    activity = header.balance || @zero
    payable = header.balance_payable || @zero
    allowance = allowance || @zero
    non_payable = Decimal.sub(activity, payable)
    available = positive_part(Decimal.add(activity, allowance))
    ledger_funded_tip = positive_part(activity)

    credit_tip_quote =
      do_tip_quote(header, allowance, credit_backed_tip_amount(), exclude_event_id: nil)

    credit_backed_tip_available? =
      credit_tip_quote.authorized? and
        Decimal.compare(credit_tip_quote.credit_backed_amount, @zero) == :gt

    available_to_tip =
      if credit_backed_tip_available? do
        Decimal.max(ledger_funded_tip, credit_backed_tip_amount())
      else
        ledger_funded_tip
      end

    cash_out_eligible =
      Decimal.min(positive_part(payable), positive_part(activity))

    %Summary{
      activity_balance: activity,
      balance_payable: payable,
      non_payable_balance: non_payable,
      credit_allowance: allowance,
      available_to_spend: available,
      available_to_tip: available_to_tip,
      credit_backed_tip_available?: credit_backed_tip_available?,
      cash_out_eligible: cash_out_eligible
    }
  end

  defp empty_summary do
    build_summary(nil, @zero)
  end

  defp ledger_header_for(%MeFile{ledger_header: %LedgerHeader{} = header}), do: header

  defp ledger_header_for(%MeFile{id: id}) when is_integer(id) do
    Repo.get_by(LedgerHeader, me_file_id: id)
  end

  defp ledger_header_for(_), do: nil

  defp positive_part(%Decimal{} = n), do: Decimal.max(n, @zero)

  defp to_dec(%Decimal{} = n), do: n
  defp to_dec(n) when is_binary(n), do: Decimal.new(n)
  defp to_dec(n) when is_integer(n), do: Decimal.new(n)
  defp to_dec(n) when is_float(n), do: Decimal.from_float(n)

  defp atomize_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    end)
  end
end
