defmodule Qlarius.Wallets do
  import Ecto.Query

  alias Qlarius.Accounts.User
  alias Qlarius.AdEvent
  alias Qlarius.Repo
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader

  def get_user_current_balance(%User{} = user) do
    get_user_ledger_header(user.id).balance
  end

  def get_user_ledger_header(%User{} = user) do
    Repo.get_by(LedgerHeader, me_file_id: user.me_file.id)
    |> Repo.preload(:user)
  end

  def get_user_ledger_header(user_id) do
    Repo.get(User, user_id)
    |> Repo.preload(:me_file)
    |> get_user_ledger_header()
  end

  def get_ledger_entry!(ledger_entry_id, %User{} = user) do
    Repo.one!(
      from(
        e in LedgerEntry,
        join: h in assoc(e, :ledger_header),
        where: e.id == ^ledger_entry_id and h.user_id == ^user.id,
        select: e,
        preload: :ad_event
      )
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
        order_by: [desc: e.inserted_at],
        limit: ^per_page,
        offset: ^offset

    entries = Repo.all(query)

    total_entries =
      from(e in LedgerEntry, where: e.ledger_header_id == ^ledger_header_id)
      |> Repo.aggregate(:count)

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
    Repo.transaction(fn ->
      # Create the AdEvent
      ad_event =
        %AdEvent{
          offer_id: offer.id,
          offer_amount: offer.amount,
          demo: offer.demo,
          throttled: offer.throttled,
          ip_address: ip_address
        }
        |> Repo.insert!()

      # Get and update the ledger header
      ledger_header = get_user_ledger_header(user.id)
      new_balance = Decimal.add(ledger_header.balance, Decimal.new("0.05"))

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      # Create the ledger entry
      # TODO - we need to get the description from the media_piece_phase
      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amount: Decimal.new("0.05"),
        running_balance: new_balance,
        description: "TODO placeholder",
        ad_event_id: ad_event.id
      }
      |> Repo.insert!()
    end)

    :ok
  end

  def create_ad_jump_event_and_update_ledger(offer, user, ip_address) do
    Repo.transaction(fn ->
      # Create AdEvent
      ad_event =
        %AdEvent{
          offer_id: offer.id,
          offer_amount: offer.amount,
          demo: offer.demo,
          throttled: offer.throttled,
          ip_address: ip_address,
          offer_complete: true
        }
        |> Repo.insert!()

      # Get user's ledger header
      ledger_header = Repo.get_by!(LedgerHeader, user_id: user.id)
      amount = Decimal.sub(offer.amount, Decimal.new("0.05"))
      new_balance = Decimal.add(ledger_header.balance, amount)

      # Update ledger header balance
      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      # Create ledger entry
      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amount: amount,
        running_balance: new_balance,
        # TODO - we need to get this from the media_piece_phase
        description: "TODO placeholder",
        ad_event_id: ad_event.id
      }
      |> Repo.insert!()

      :ok
    end)
  end
end
