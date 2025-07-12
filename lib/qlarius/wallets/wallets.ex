defmodule Qlarius.Wallets.Wallets do
  import Ecto.Query
  require Logger

  alias Qlarius.Repo
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Sponster.Ads.MediaPiecePhase
  alias Qlarius.Wallets.MeFileBalanceBroadcaster

  def get_me_file_ledger_header_balance(%MeFile{} = me_file) do
    case Repo.get_by(LedgerHeader, me_file_id: me_file.id) do
      nil -> Decimal.new("0.00")
      header -> header.balance || Decimal.new("0.00")
    end
  end

  def get_me_file_ledger_header(%MeFile{} = me_file) do
    Repo.get_by(LedgerHeader, me_file_id: me_file.id)
  end

  def get_ledger_entry!(ledger_entry_id, %MeFile{} = me_file) do
    Repo.one!(
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

  def update_ledgers_from_ad_event(ad_event) do
    phase = Repo.get!(MediaPiecePhase, ad_event.media_piece_phase_id)
    phase_description = phase.desc
    campaign = Repo.get!(Campaign, ad_event.campaign_id) |> Repo.preload(:marketer)
    marketer_name = campaign.marketer.business_name
    update_me_file_ledger_from_ad_event(ad_event, phase_description, marketer_name)

    # Only update recipient ledger if there is a recipient_id
    if ad_event.recipient_id do
      update_recipient_ledger_from_ad_event(ad_event, phase_description)
    end

    update_campaign_ledger_from_ad_event(ad_event, phase_description)
    update_sponster_ledger_from_ad_event(ad_event, phase_description, marketer_name)
  end

  def update_me_file_ledger_from_ad_event(ad_event, phase_description, marketer_name) do
    Repo.transaction(fn ->
      # Check if ledger entry already exists for this ad_event
      ledger_header = Repo.get_by!(LedgerHeader, me_file_id: ad_event.me_file_id)

      existing_ledger_entry =
        Repo.one(
          from e in LedgerEntry,
            join: h in assoc(e, :ledger_header),
            where: e.ad_event_id == ^ad_event.id and h.me_file_id == ^ad_event.me_file_id
        )

      if existing_ledger_entry do
        {:error, :ledger_entry_exists}
      else
        new_balance =
          Decimal.add(ledger_header.balance, ad_event.event_me_file_collect_amt)

        new_balance_payable =
          if ad_event.is_payable do
            Decimal.add(ledger_header.balance, ad_event.event_me_file_collect_amt)
          else
            ledger_header.balance
          end

        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_me_file_collect_amt,
          running_balance: new_balance,
          description: "#{phase_description} - #{String.upcase(marketer_name)}",
          ad_event_id: ad_event.id,
          running_balance_payable: new_balance_payable
        })
        |> Repo.insert!()

        # Update the ledger header
        ledger_header
        |> Ecto.Changeset.change(balance: new_balance, balance_payable: new_balance_payable)
        |> Repo.update!()

        MeFileBalanceBroadcaster.broadcast_me_file_balance_update(
          ad_event.me_file_id,
          new_balance
        )
      end
    end)
  end

  def update_recipient_ledger_from_ad_event(ad_event, phase_description) do
    Repo.transaction(fn ->
      # Check if ledger entry already exists for this ad_event
      ledger_header = Repo.get_by!(LedgerHeader, recipient_id: ad_event.recipient_id)

      existing_ledger_entry =
        Repo.one(
          from e in LedgerEntry,
            join: h in assoc(e, :ledger_header),
            where: e.ad_event_id == ^ad_event.id and h.recipient_id == ^ad_event.recipient_id
        )

      if existing_ledger_entry do
        {:error, :ledger_entry_exists}
      else
        # Log initial balance and amounts
        Logger.debug("Initial Ledger Header Balance: #{ledger_header.balance}")
        Logger.debug("Event Recipient Collect Amount: #{ad_event.event_recipient_collect_amt}")

        Logger.debug(
          "Event Sponster to Recipient Amount: #{ad_event.event_sponster_to_recipient_amt}"
        )

        # Revshare from mefile to recipient
        new_balance_from_me_file =
          Decimal.add(ledger_header.balance, ad_event.event_recipient_collect_amt)

        Logger.debug("New Balance from MeFile: #{new_balance_from_me_file}")

        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_recipient_collect_amt,
          running_balance: new_balance_from_me_file,
          description: "RevShare - #{phase_description} - MeFile: #{ad_event.me_file_id}",
          ad_event_id: ad_event.id
        })
        |> Repo.insert!()

        # Revshare from sponster to recipient
        new_balance_from_sponster =
          Decimal.add(new_balance_from_me_file, ad_event.event_sponster_to_recipient_amt)

        Logger.debug("New Balance from Sponster: #{new_balance_from_sponster}")

        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_sponster_to_recipient_amt,
          running_balance: new_balance_from_sponster,
          description: "RevShare - #{phase_description} - SPONSTER",
          ad_event_id: ad_event.id
        })
        |> Repo.insert!()

        # Update the ledger header with the final ledger entry running balance
        ledger_header
        |> Ecto.Changeset.change(balance: new_balance_from_sponster)
        |> Repo.update!()
      end
    end)
  end

  def update_campaign_ledger_from_ad_event(ad_event, phase_description) do
    Repo.transaction(fn ->
      # Check if ledger entry already exists for this ad_event
      ledger_header = Repo.get_by!(LedgerHeader, campaign_id: ad_event.campaign_id)

      existing_ledger_entry =
        Repo.one(
          from e in LedgerEntry,
            join: h in assoc(e, :ledger_header),
            where: e.ad_event_id == ^ad_event.id and h.campaign_id == ^ad_event.campaign_id
        )

      if existing_ledger_entry do
        {:error, :ledger_entry_exists}
      else
        new_balance = Decimal.sub(ledger_header.balance, ad_event.event_marketer_cost_amt)
        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: Decimal.negate(ad_event.event_marketer_cost_amt),
          running_balance: new_balance,
          description: "Ad Engagement - #{phase_description} - MeFile: #{ad_event.me_file_id}",
          ad_event_id: ad_event.id
        })
        |> Repo.insert!()

        # Update the ledger header
        ledger_header
        |> Ecto.Changeset.change(balance: new_balance)
        |> Repo.update!()
      end
    end)
  end

  def update_sponster_ledger_from_ad_event(ad_event, phase_description, marketer_name) do
    Repo.transaction(fn ->
      # Get the master sponster ledger header (with id 1
      ledger_header = Repo.get!(LedgerHeader, 1)

      existing_ledger_entry =
        Repo.one(
          from e in LedgerEntry,
            where: e.ad_event_id == ^ad_event.id and e.ledger_header_id == 1
        )

      if existing_ledger_entry do
        {:error, :ledger_entry_exists}
      else
        new_balance = Decimal.add(ledger_header.balance, ad_event.event_sponster_collect_amt)
        # Create a new ledger entry for the ad event
        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_sponster_collect_amt,
          running_balance: new_balance,
          description:
            "Ad Revenue - #{marketer_name} - #{phase_description} - MeFile: #{ad_event.me_file_id}",
          ad_event_id: ad_event.id
        })
        |> Repo.insert!()

        # Update the ledger header
        ledger_header
        |> Ecto.Changeset.change(balance: new_balance)
        |> Repo.update!()
      end
    end)
  end

  # Simulate topping up by $2. Useful when debugging.
  def fake_topup(user) do
    Repo.transaction(fn ->
      ledger_header = user.me_file.ledger_header

      amount = Decimal.new(2)

      new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), amount)

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: "Top up"
      }
      |> Repo.insert!()
    end)

    :ok
  end
end
