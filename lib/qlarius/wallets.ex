defmodule Qlarius.Wallets do
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.AdEvent
  # alias Qlarius.Repo
  # alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{LedgerHeader, LedgerEntry, MeFile}

  def get_user_current_balance(%User{} = user) do
    case get_user_ledger_header(user.id) do
      nil -> Decimal.new("0.00")
      header -> header.balance || Decimal.new("0.00")
    end
  end

  @doc """
  Gets a user's ledger header from the legacy database.
  """
  def get_user_ledger_header(user_id) when is_integer(user_id) do
    LegacyRepo.one(
      from h in LedgerHeader,
        join: m in MeFile,
        on: h.me_file_id == m.id,
        where: m.user_id == ^user_id
    )
  end

  def get_ledger_entry!(ledger_entry_id, %User{} = user) do
    LegacyRepo.one!(
      from e in LedgerEntry,
        join: h in assoc(e, :ledger_header),
        join: m in MeFile,
        on: h.me_file_id == m.id,
        where: e.id == ^ledger_entry_id and m.user_id == ^user.id,
        select: e,
        preload: :ad_event
    )
  end

  @doc """
  Gets a paginated list of ledger entries for a ledger header.
  """
  def list_ledger_entries(ledger_header_id, page, per_page \\ 20) do
    offset = (page - 1) * per_page

    query =
      from e in LedgerEntry,
        where: e.ledger_header_id == ^ledger_header_id,
        order_by: [desc: e.created_at],
        limit: ^per_page,
        offset: ^offset

    entries = LegacyRepo.all(query)

    total_entries =
      from(e in LedgerEntry, where: e.ledger_header_id == ^ledger_header_id)
      |> LegacyRepo.aggregate(:count)

    total_pages = ceil(total_entries / per_page)

    %{
      entries: entries,
      page_number: page,
      page_size: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  def create_ad_event_and_update_ledger(offer, user, ip_address) do
    LegacyRepo.transaction(fn ->
      me_file = get_user_me_file(user.id)
      ledger_header = get_user_ledger_header(user.id)

      # Create the AdEvent
      ad_event =
        %AdEvent{
          offer_id: offer.id,
          offer_amount: offer.offer_amt,
          demo: offer.demo,
          throttled: offer.throttled,
          ip_address: ip_address
        }
        |> LegacyRepo.insert!()

      # Update the ledger header
      new_balance = Decimal.add(ledger_header.balance || Decimal.new("0.00"), Decimal.new("0.05"))

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> LegacyRepo.update!()

      # Create the ledger entry
      %LedgerEntry{}
      |> LedgerEntry.changeset(%{
        ledger_header_id: ledger_header.id,
        amt: Decimal.new("0.05"),
        running_balance: new_balance,
        description: "Ad view payment",
        ad_event_id: ad_event.id
      })
      |> LegacyRepo.insert!()
    end)

    :ok
  end

  def create_ad_jump_event_and_update_ledger(offer, user, ip_address) do
    LegacyRepo.transaction(fn ->
      me_file = get_user_me_file(user.id)
      ledger_header = get_user_ledger_header(user.id)

      # Create AdEvent
      ad_event =
        %AdEvent{
          offer_id: offer.id,
          offer_amount: offer.offer_amt,
          demo: offer.demo,
          throttled: offer.throttled,
          ip_address: ip_address,
          offer_complete: true
        }
        |> LegacyRepo.insert!()

      # Calculate jump payment (full offer amount minus initial view payment)
      amount = Decimal.sub(offer.offer_amt, Decimal.new("0.05"))
      new_balance = Decimal.add(ledger_header.balance || Decimal.new("0.00"), amount)

      # Update ledger header balance
      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> LegacyRepo.update!()

      # Create ledger entry
      %LedgerEntry{}
      |> LedgerEntry.changeset(%{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: "Ad jump payment",
        ad_event_id: ad_event.id
      })
      |> LegacyRepo.insert!()

      :ok
    end)
  end

  defp get_user_me_file(user_id) do
    LegacyRepo.one!(from m in MeFile, where: m.user_id == ^user_id)
  end
end
