defmodule Qlarius.Wallets do
  import Ecto.Query

  alias Qlarius.Accounts.MeFile
  alias Qlarius.Accounts.User
  alias Qlarius.AdEvent
  alias Qlarius.Offer
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

  @click_amount Decimal.new("0.05")

  def create_ad_event_and_update_ledger(%Offer{} = offer, %User{} = user, ip_address) do
    Repo.transaction(fn ->
      me_file = %MeFile{} = user.me_file
      ledger_header = me_file.ledger_header

      ad_event =
        %AdEvent{
          offer: offer,
          offer_bid_amount: offer.amount,
          is_throttled: offer.is_throttled,
          is_offer_complete: false,
          ip_address: ip_address
        }
        |> Repo.insert!()

      new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), @click_amount)

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amount: @click_amount,
        running_balance: new_balance,
        description: "Ad view payment",
        ad_event_id: ad_event.id
      }
      |> Repo.insert!()
    end)

    :ok
  end

  def create_ad_jump_event_and_update_ledger(offer, user, ip_address) do
    Repo.transaction(fn ->
      ledger_header = user.me_file.ledger_header

      ad_event =
        %AdEvent{
          offer: offer,
          offer_bid_amount: offer.amount,
          is_throttled: offer.is_throttled,
          is_offer_complete: true,
          ip_address: ip_address,
          url: offer.media_piece.jump_url
        }
        |> Repo.insert!()

      jump_amount = Decimal.sub(offer.amount, @click_amount)
      new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), @click_amount)

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amount: jump_amount,
        running_balance: new_balance,
        description: "Ad jump payment",
        ad_event_id: ad_event.id
      }
      |> Repo.insert!()
    end)

    :ok
  end
end
