defmodule Qlarius.Wallets do
  import Ecto.Query
  require Logger

  alias Qlarius.Repo
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry, LedgerEvent}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Sponster.Ads.MediaPiecePhase
  alias Qlarius.Wallets.MeFileBalanceBroadcaster
  # Added User alias for get_user_current_balance function
  alias Qlarius.Accounts.User
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Sponster.Recipient

  # Added missing function that was being called from multiple LiveView modules
  def get_user_current_balance(%User{} = user) do
    # Delegate to existing function using user's me_file
    get_me_file_ledger_header_balance(user.me_file)
  end

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

  # TODO: update these ledger updates into a Ecto.Multi so that all pass or all fail.

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

  # Simulate topping up by $0.50. Useful when debugging.
  def fake_topup(user) do
    Repo.transaction(fn ->
      ledger_header = user.me_file.ledger_header

      amount = Decimal.new("0.50")

      new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), amount)

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: "Top up - GIFT"
      }
      |> Repo.insert!()
    end)

    :ok
  end

  def get_tiqit_purchase_details(tiqit_id) do
    tiqit =
      Repo.get(Tiqit, tiqit_id)
      |> Repo.preload(
        tiqit_class: [
          :content_piece,
          :content_group,
          content_piece: [
            content_group: [
              catalog: [:creator]
            ]
          ],
          content_group: [
            catalog: [:creator]
          ]
        ]
      )

    if tiqit do
      # Handle different tiqit class types (content_piece vs content_group)
      creator =
        cond do
          tiqit.tiqit_class.content_group && tiqit.tiqit_class.content_group.catalog ->
            tiqit.tiqit_class.content_group.catalog.creator

          tiqit.tiqit_class.content_piece && tiqit.tiqit_class.content_piece.content_group ->
            tiqit.tiqit_class.content_piece.content_group.catalog.creator

          true ->
            nil
        end

      content_group =
        cond do
          tiqit.tiqit_class.content_group ->
            tiqit.tiqit_class.content_group

          tiqit.tiqit_class.content_piece && tiqit.tiqit_class.content_piece.content_group ->
            tiqit.tiqit_class.content_piece.content_group

          true ->
            nil
        end

      %{
        tiqit: tiqit,
        creator: creator,
        content_group: content_group,
        content_piece: tiqit.tiqit_class.content_piece
      }
    else
      nil
    end
  end

  # InstaTip functions

  @doc """
  Validates if a user has sufficient funds for a tip amount.
  """
  def validate_sufficient_funds(%User{} = user, amount) do
    current_balance = get_user_current_balance(user)
    Decimal.compare(current_balance, amount) != :lt
  end

  @doc """
  Gets or creates a ledger header for a recipient.
  """
  def get_or_create_recipient_ledger_header(%Recipient{} = recipient) do
    case Repo.get_by(LedgerHeader, recipient_id: recipient.id) do
      nil ->
        # Create a new ledger header for the recipient
        %LedgerHeader{}
        |> LedgerHeader.changeset(%{
          description: "Ledger for #{recipient.name}",
          balance: Decimal.new("0.00"),
          balance_payable: Decimal.new("0.00"),
          recipient_id: recipient.id
        })
        |> Repo.insert!()

      ledger_header ->
        ledger_header
    end
  end

  @doc """
  Creates an InstaTip request and enqueues the processing job.
  """
  def create_insta_tip_request(
        %User{} = from_user,
        %Recipient{} = to_recipient,
        amount,
        %User{} = requested_by_user
      ) do
    Repo.transaction(fn ->
      # Get or create ledger headers
      from_ledger = get_me_file_ledger_header(from_user.me_file)
      to_ledger = get_or_create_recipient_ledger_header(to_recipient)

      # Create the ledger event
      ledger_event =
        %LedgerEvent{}
        |> LedgerEvent.changeset(%{
          from_ledger_id: from_ledger.id,
          to_ledger_id: to_ledger.id,
          amount: amount,
          status: "pending",
          description: "InstaTip to #{to_recipient.name}",
          requested_by_user_id: requested_by_user.id
        })
        |> Repo.insert!()

      # Enqueue the processing job
      %{ledger_event_id: ledger_event.id}
      |> Qlarius.Jobs.ProcessInstaTip.new()
      |> Oban.insert()

      ledger_event
    end)
  end

  @doc """
  Processes a pending InstaTip ledger event.
  """
  def process_insta_tip(%LedgerEvent{} = ledger_event) do
    Repo.transaction(fn ->
      # Reload with required nested associations
      ledger_event =
        Repo.preload(ledger_event,
          from_ledger: [:me_file],
          to_ledger: [:recipient],
          requested_by_user: []
        )

      # Check if user still has sufficient funds
      current_balance = ledger_event.from_ledger.balance

      if Decimal.compare(current_balance, ledger_event.amount) == :lt do
        # Update status to failed
        ledger_event
        |> Ecto.Changeset.change(status: "failed")
        |> Repo.update!()

        {:error, :insufficient_funds}
      else
        # Update status to processing
        ledger_event
        |> Ecto.Changeset.change(status: "processing")
        |> Repo.update!()

        # Process the transfer
        process_ledger_transfer(ledger_event)

        # Update status to completed
        ledger_event
        |> Ecto.Changeset.change(status: "completed")
        |> Repo.update!()

        {:ok, ledger_event}
      end
    end)
  end

  defp process_ledger_transfer(%LedgerEvent{} = ledger_event) do
    # Deduct from sender's ledger
    new_from_balance = Decimal.sub(ledger_event.from_ledger.balance, ledger_event.amount)

    ledger_event.from_ledger
    |> Ecto.Changeset.change(balance: new_from_balance)
    |> Repo.update!()

    # Create debit entry for sender
    %LedgerEntry{}
    |> LedgerEntry.changeset(%{
      ledger_header_id: ledger_event.from_ledger_id,
      amt: Decimal.negate(ledger_event.amount),
      running_balance: new_from_balance,
      description: "InstaTip to #{ledger_event.to_ledger.recipient.name}"
    })
    |> Repo.insert!()

    # Add to recipient's ledger
    new_to_balance = Decimal.add(ledger_event.to_ledger.balance, ledger_event.amount)

    ledger_event.to_ledger
    |> Ecto.Changeset.change(balance: new_to_balance)
    |> Repo.update!()

    # Create credit entry for recipient
    %LedgerEntry{}
    |> LedgerEntry.changeset(%{
      ledger_header_id: ledger_event.to_ledger_id,
      amt: ledger_event.amount,
      running_balance: new_to_balance,
      description: "InstaTip from #{ledger_event.requested_by_user.email}"
    })
    |> Repo.insert!()

    # Broadcast balance update
    MeFileBalanceBroadcaster.broadcast_me_file_balance_update(
      ledger_event.from_ledger.me_file_id,
      new_from_balance
    )
  end
end
