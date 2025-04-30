defmodule Qlarius.Wallets do
  import Ecto.Query

  alias Qlarius.LegacyRepo
  alias Qlarius.Legacy.{LedgerHeader, LedgerEntry, MeFile, Campaign, Marketer, MediaPiecePhase}

  def get_me_file_ledger_header_balance(%MeFile{} = me_file) do
    case LegacyRepo.get_by(LedgerHeader, me_file_id: me_file.id) do
      nil -> Decimal.new("0.00")
      header -> header.balance || Decimal.new("0.00")
    end
  end

  @doc """
  Gets a me_file's ledger header from the legacy database.
  """
  def get_me_file_ledger_header(%MeFile{} = me_file) do
    LegacyRepo.get_by(LedgerHeader, me_file_id: me_file.id)
  end

  def get_ledger_entry!(ledger_entry_id, %MeFile{} = me_file) do
    LegacyRepo.one!(
      from e in LedgerEntry,
        join: h in assoc(e, :ledger_header),
        where: e.id == ^ledger_entry_id and h.me_file_id == ^me_file.id,
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

  def update_ledgers_from_ad_event(ad_event) do
    LegacyRepo.transaction(fn ->
      # MeFile Ledger Entry first
      # Check if a me_file ledger entry already exists for this ad_event
      existing_me_file_ledger_entry = LegacyRepo.one(
        from e in LedgerEntry,
        join: h in assoc(e, :ledger_header),
        join: m in MeFile,
        on: h.me_file_id == m.id,
        where: e.ad_event_id == ^ad_event.id and m.id == ^ad_event.me_file_id
      )

      if existing_me_file_ledger_entry do
        {:error, :ledger_entry_exists}
      else
        me_file = LegacyRepo.get!(MeFile, ad_event.me_file_id)
        campaign = LegacyRepo.get!(Campaign, ad_event.campaign_id)
        marketer = LegacyRepo.get!(Marketer, campaign.marketer_id)
        phase = LegacyRepo.get!(MediaPiecePhase, ad_event.media_piece_phase_id)
        ledger_header = LegacyRepo.get_by!(LedgerHeader, me_file_id: me_file.id)
        new_balance = Decimal.add(ledger_header.balance || Decimal.new("0.00"), ad_event.event_me_file_collect_amt)
        new_balance_payable = if ad_event.is_payable do
          Decimal.add(ledger_header.balance || Decimal.new("0.00"), ad_event.event_me_file_collect_amt)
        else
          ledger_header.balance || Decimal.new("0.00")
        end

        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_me_file_collect_amt,
          running_balance: new_balance,
          description: "#{phase.desc} - #{String.upcase(marketer.business_name)}",
          ad_event_id: ad_event.id,
          running_balance_payable: new_balance_payable
        })
        |> LegacyRepo.insert!()

        # Update the ledger header
        ledger_header
        |> Ecto.Changeset.change(balance: new_balance, balance_payable: new_balance_payable)
        |> LegacyRepo.update!()
      end
    end)
  end

end
