defmodule Qlarius.Referrals do
  import Ecto.Query, warn: false
  alias Qlarius.Repo

  alias Qlarius.Referrals.{Referral, ReferralClick, ReferralCredit}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Creators.Creator
  alias Qlarius.Sponster.Recipient
  alias Qlarius.Accounts.User

  def generate_referral_code(type) when type in ["mefile", "creator", "recipient"] do
    prefix =
      case type do
        "mefile" -> "m-"
        "creator" -> "c-"
        "recipient" -> "r-"
      end

    uuid =
      Ecto.UUID.generate()
      |> String.replace("-", "")
      |> String.slice(0..11)
      |> String.downcase()

    "#{prefix}#{uuid}"
  end

  def set_referral_code(me_file, code) do
    me_file
    |> Ecto.Changeset.change(%{referral_code: code})
    |> Repo.update()
  end

  def lookup_referrer_by_code(""), do: {:error, :not_found}
  def lookup_referrer_by_code(nil), do: {:error, :not_found}

  def lookup_referrer_by_code(code) when is_binary(code) do
    code = String.trim(code)

    if code == "" do
      {:error, :not_found}
    else
      do_lookup_referrer(code)
    end
  end

  defp do_lookup_referrer(code) do
    cond do
      String.starts_with?(code, "m-") ->
        _uuid = String.replace_prefix(code, "m-", "")
        me_file = from(m in MeFile, where: m.referral_code == ^code, limit: 1) |> Repo.one()

        if me_file do
          {:ok, "mefile", me_file.id}
        else
          {:error, :not_found}
        end

      String.starts_with?(code, "c-") ->
        _uuid = String.replace_prefix(code, "c-", "")
        creator = from(c in Creator, where: c.referral_code == ^code, limit: 1) |> Repo.one()

        if creator do
          {:ok, "creator", creator.id}
        else
          {:error, :not_found}
        end

      String.starts_with?(code, "r-") ->
        _uuid = String.replace_prefix(code, "r-", "")
        recipient = from(r in Recipient, where: r.referral_code == ^code, limit: 1) |> Repo.one()

        if recipient do
          {:ok, "recipient", recipient.id}
        else
          {:error, :not_found}
        end

      true ->
        # First try to find a MeFile with this referral_code
        me_file = from(m in MeFile, where: m.referral_code == ^code, limit: 1) |> Repo.one()

        if me_file do
          {:ok, "mefile", me_file.id}
        else
          # Fall back to user alias
          user = Repo.get_by(User, alias: code)

          if user do
            me_file = Repo.preload(user, :me_file).me_file

            if me_file do
              {:ok, "mefile", me_file.id}
            else
              {:error, :not_found}
            end
          else
            {:error, :not_found}
          end
        end
    end
  end

  def create_referral(referrer_type, referrer_id, referred_me_file_id) do
    attrs = %{
      referrer_type: referrer_type,
      referrer_id: referrer_id
    }

    Referral.create_changeset(attrs, referred_me_file_id)
    |> Repo.insert()
  end

  def get_referral_by_me_file(me_file_id) do
    case Repo.get_by(Referral, referred_me_file_id: me_file_id) do
      nil -> nil
      referral -> load_referrer_info(referral)
    end
  end

  defp load_referrer_info(%Referral{referrer_type: "mefile", referrer_id: referrer_id} = referral) do
    case Repo.get(MeFile, referrer_id) do
      nil ->
        referral

      me_file ->
        me_file = Repo.preload(me_file, :user)
        Map.put(referral, :referrer_alias, mask_alias(me_file.user.alias))
    end
  end

  defp load_referrer_info(referral), do: referral

  def can_add_referral?(me_file_id) do
    case get_referral_by_me_file(me_file_id) do
      nil ->
        me_file = Repo.get!(MeFile, me_file_id) |> Repo.preload(:user)
        registration_date = DateTime.from_naive!(me_file.user.inserted_at, "Etc/UTC")
        grace_period_end = DateTime.add(registration_date, 10, :day)
        DateTime.compare(DateTime.utc_now(), grace_period_end) == :lt

      referral ->
        click_count = count_referral_clicks(referral.id)
        click_count == 0
    end
  end

  def update_referral(me_file_id, referral_code) do
    with true <- can_add_referral?(me_file_id),
         {:ok, referrer_type, referrer_id} <- lookup_referrer_by_code(referral_code) do
      existing_referral = get_referral_by_me_file(me_file_id)

      if existing_referral do
        existing_referral
        |> Referral.changeset(%{
          referrer_type: referrer_type,
          referrer_id: referrer_id
        })
        |> Repo.update()
      else
        create_referral(referrer_type, referrer_id, me_file_id)
      end
    else
      false -> {:error, :grace_period_expired}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_referral_click(referral_id, ad_event_id) do
    result =
      %ReferralClick{}
      |> ReferralClick.changeset(%{
        referral_id: referral_id,
        ad_event_id: ad_event_id
      })
      |> Repo.insert()

    case result do
      {:ok, click} ->
        referral = Repo.get(Referral, referral_id)

        if referral && referral.referrer_type == "mefile" do
          pending_count = get_pending_clicks_for_me_file(referral.referrer_id)

          Qlarius.Wallets.MeFileStatsBroadcaster.broadcast_pending_referral_clicks_updated(
            referral.referrer_id,
            pending_count
          )
        end

        {:ok, click}

      error ->
        error
    end
  end

  def count_referral_clicks(referral_id) do
    from(rc in ReferralClick, where: rc.referral_id == ^referral_id, select: count(rc.id))
    |> Repo.one()
  end

  def count_unpaid_clicks(referral_id) do
    total_clicks =
      from(rc in ReferralClick,
        where: rc.referral_id == ^referral_id,
        select: count(rc.id)
      )
      |> Repo.one()

    paid_clicks =
      from(cred in ReferralCredit,
        where: cred.referral_id == ^referral_id,
        select: coalesce(sum(cred.clicks_paid_count), 0)
      )
      |> Repo.one()

    max(0, total_clicks - paid_clicks)
  end

  def count_paid_clicks(referral_id) do
    from(rc in ReferralCredit,
      where: rc.referral_id == ^referral_id,
      select: sum(rc.clicks_paid_count)
    )
    |> Repo.one() || 0
  end

  def get_total_paid_amount(referral_id) do
    total_clicks_paid =
      from(rc in ReferralCredit,
        where: rc.referral_id == ^referral_id,
        select: coalesce(sum(rc.clicks_paid_count), 0)
      )
      |> Repo.one()

    Decimal.mult(Decimal.new("0.01"), total_clicks_paid)
  end

  def list_referrals_for_referrer(referrer_type, referrer_id) do
    from(r in Referral,
      where: r.referrer_type == ^referrer_type,
      where: r.referrer_id == ^referrer_id,
      where: r.status == "active",
      where: r.expires_at > ^DateTime.utc_now(),
      preload: [referred_me_file: :user],
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(fn referral ->
      total_clicks = count_referral_clicks(referral.id)
      paid_clicks = count_paid_clicks(referral.id)
      pending_clicks = total_clicks - paid_clicks
      total_paid = get_total_paid_amount(referral.id)

      now = DateTime.utc_now()
      is_expired = DateTime.compare(referral.expires_at, now) == :lt

      days_remaining =
        if is_expired do
          0
        else
          DateTime.diff(referral.expires_at, now, :day)
        end

      %{
        referral: referral,
        alias: mask_alias(referral.referred_me_file.user.alias),
        total_clicks: total_clicks,
        paid_clicks: paid_clicks,
        pending_clicks: pending_clicks,
        total_paid: total_paid,
        is_expired: is_expired,
        days_remaining: days_remaining
      }
    end)
  end

  def get_unpaid_clicks_by_referrer do
    from(r in Referral,
      where: r.status == "active",
      where: r.expires_at > ^DateTime.utc_now(),
      select: {r.referrer_type, r.referrer_id, r.id}
    )
    |> Repo.all()
    |> Enum.map(fn {referrer_type, referrer_id, referral_id} ->
      total_clicks = count_referral_clicks(referral_id)
      paid_clicks = count_paid_clicks(referral_id)
      pending = total_clicks - paid_clicks

      if pending > 0 do
        {referrer_type, referrer_id, referral_id, pending}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def get_total_pending_clicks_for_referrer(referrer_type, referrer_id) do
    from(r in Referral,
      where: r.referrer_type == ^referrer_type,
      where: r.referrer_id == ^referrer_id,
      where: r.status == "active",
      where: r.expires_at > ^DateTime.utc_now(),
      select: r.id
    )
    |> Repo.all()
    |> Enum.map(fn referral_id ->
      total_clicks = count_referral_clicks(referral_id)
      paid_clicks = count_paid_clicks(referral_id)
      max(0, total_clicks - paid_clicks)
    end)
    |> Enum.sum()
  end

  def get_pending_clicks_for_me_file(me_file_id) when is_integer(me_file_id) do
    get_total_pending_clicks_for_referrer("mefile", me_file_id)
  end

  def get_pending_clicks_for_me_file(%MeFile{id: me_file_id}) do
    get_pending_clicks_for_me_file(me_file_id)
  end

  def process_referrer_payout(referrer_type, referrer_id) do
    alias Qlarius.Wallets.{LedgerHeader, LedgerEntry, MeFileStatsBroadcaster}
    alias Ecto.Multi

    pending_referrals =
      from(r in Referral,
        where: r.referrer_type == ^referrer_type,
        where: r.referrer_id == ^referrer_id,
        where: r.status == "active",
        where: r.expires_at > ^DateTime.utc_now(),
        select: r.id
      )
      |> Repo.all()
      |> Enum.map(fn referral_id ->
        total_clicks = count_referral_clicks(referral_id)
        paid_clicks = count_paid_clicks(referral_id)
        pending = total_clicks - paid_clicks

        if pending > 0 do
          {referral_id, pending}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(pending_referrals) do
      {:ok, :no_pending_clicks}
    else
      total_clicks = Enum.reduce(pending_referrals, 0, fn {_id, count}, acc -> acc + count end)
      total_amount = Decimal.mult(Decimal.new("0.01"), total_clicks)

      ledger_header = get_ledger_for_referrer(referrer_type, referrer_id)

      if is_nil(ledger_header) do
        {:error, :no_ledger}
      else
        new_balance = Decimal.add(ledger_header.balance, total_amount)

        Multi.new()
        |> Multi.insert(:ledger_entry, fn _ ->
          LedgerEntry.changeset(%LedgerEntry{}, %{
            ledger_header_id: ledger_header.id,
            amt: total_amount,
            description: "Referral Payout - #{total_clicks} clicks",
            meta_1: "Referral Bonus",
            running_balance: new_balance
          })
        end)
        |> Multi.run(:referral_credits, fn _repo, %{ledger_entry: entry} ->
          results =
            Enum.reduce_while(pending_referrals, {:ok, []}, fn {referral_id, click_count},
                                                               {:ok, acc} ->
              case ReferralCredit.changeset(%ReferralCredit{}, %{
                     referral_id: referral_id,
                     ledger_entry_id: entry.id,
                     clicks_paid_count: click_count
                   })
                   |> Repo.insert() do
                {:ok, credit} ->
                  {:cont, {:ok, [credit | acc]}}

                {:error, changeset} ->
                  {:halt, {:error, changeset}}
              end
            end)

          case results do
            {:ok, credits} -> {:ok, Enum.reverse(credits)}
            {:error, changeset} -> {:error, changeset}
          end
        end)
        |> Multi.update(:update_balance, fn _changes ->
          ledger_header
          |> Ecto.Changeset.change(balance: new_balance)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, _result} ->
            if referrer_type == "mefile" do
              MeFileStatsBroadcaster.broadcast_balance_updated(referrer_id, new_balance)
              new_pending_count = get_pending_clicks_for_me_file(referrer_id)

              MeFileStatsBroadcaster.broadcast_pending_referral_clicks_updated(
                referrer_id,
                new_pending_count
              )
            end

            {:ok, %{clicks: total_clicks, amount: total_amount}}

          {:error, step, changeset, _changes} ->
            {:error, {step, changeset}}
        end
      end
    end
  end

  defp get_ledger_for_referrer("mefile", me_file_id) do
    Repo.get_by(Qlarius.Wallets.LedgerHeader, me_file_id: me_file_id)
  end

  defp get_ledger_for_referrer("creator", creator_id) do
    Repo.get_by(Qlarius.Wallets.LedgerHeader, creator_id: creator_id)
  end

  defp get_ledger_for_referrer("recipient", recipient_id) do
    Repo.get_by(Qlarius.Wallets.LedgerHeader, recipient_id: recipient_id)
  end

  defp mask_alias(alias_string) do
    length = String.length(alias_string)

    cond do
      length <= 7 ->
        alias_string

      true ->
        first_two = String.slice(alias_string, 0..1)
        last_five = String.slice(alias_string, -5..-1//1)
        dots = String.duplicate("•", length - 7)
        "#{first_two}#{dots}#{last_five}"
    end
  end
end
