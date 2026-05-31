defmodule Qlarius.Wallets do
  import Ecto.Query
  require Logger

  alias Qlarius.Repo
  alias Qlarius.Wallets.{LedgerHeader, LedgerEntry, LedgerEvent}
  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Sponster.Campaigns.Campaign
  alias Qlarius.Sponster.Ads.MediaPiecePhase
  alias Qlarius.Wallets.MeFileStatsBroadcaster
  # Added User alias for get_user_current_balance function
  alias Qlarius.Accounts.User
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Sponster.Recipient

  @sponster_ledger_header_id 1

  def sponster_ledger_header_id, do: @sponster_ledger_header_id

  def sponster_ledger_header do
    Repo.get(LedgerHeader, @sponster_ledger_header_id)
  end

  def sponster_ledger_header! do
    Repo.get!(LedgerHeader, @sponster_ledger_header_id)
  end

  def get_ledger_entry_for_header!(ledger_entry_id, ledger_header_id) do
    Repo.one!(
      from e in LedgerEntry,
        where: e.id == ^ledger_entry_id and e.ledger_header_id == ^ledger_header_id,
        preload: [
          ad_event: [
            :campaign,
            campaign: :marketer,
            media_piece: [:media_piece_type, :ad_category]
          ]
        ]
    )
  end

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
        order_by: [desc: e.created_at, desc: e.id],
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

    with {:ok, new_balance} <-
           update_me_file_ledger_from_ad_event(ad_event, phase_description, marketer_name) do
      if ad_event.recipient_id do
        update_recipient_ledger_from_ad_event(ad_event, phase_description)
      end

      update_campaign_ledger_from_ad_event(ad_event, phase_description)
      update_sponster_ledger_from_ad_event(ad_event, phase_description, marketer_name)

      MeFileStatsBroadcaster.broadcast_ad_event_collected(
        ad_event.me_file_id,
        new_balance,
        offer_complete: ad_event.is_offer_complete
      )

      {:ok, new_balance}
    end
  end

  def update_me_file_ledger_from_ad_event(ad_event, phase_description, marketer_name) do
    Repo.transaction(fn ->
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

        meta_1 = phase_description_to_meta_1(phase_description)

        %LedgerEntry{}
        |> LedgerEntry.changeset(%{
          ledger_header_id: ledger_header.id,
          amt: ad_event.event_me_file_collect_amt,
          running_balance: new_balance,
          description: String.upcase(marketer_name),
          meta_1: meta_1,
          ad_event_id: ad_event.id,
          running_balance_payable: new_balance_payable
        })
        |> Repo.insert!()

        ledger_header
        |> Ecto.Changeset.change(balance: new_balance, balance_payable: new_balance_payable)
        |> Repo.update!()

        {:ok, new_balance}
      end
    end)
    |> normalize_transaction_result()
  end

  defp normalize_transaction_result({:ok, {:ok, new_balance}}), do: {:ok, new_balance}
  defp normalize_transaction_result({:ok, {:error, reason}}), do: {:error, reason}
  defp normalize_transaction_result({:error, reason}), do: {:error, reason}

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
      ledger_header = sponster_ledger_header!()

      existing_ledger_entry =
        Repo.one(
          from e in LedgerEntry,
            where:
              e.ad_event_id == ^ad_event.id and
                e.ledger_header_id == ^@sponster_ledger_header_id
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
        description: "Top up - GIFT",
        meta_1: "Gift"
      }
      |> Repo.insert!()
    end)

    :ok
  end

  @daily_gift_meta "Daily Gift"
  @daily_gift_amount Decimal.new("0.50")

  def daily_gift_amount, do: @daily_gift_amount

  def daily_gift_available?(%User{} = user) do
    not daily_gift_cooldown_active?(user)
  end

  def claim_daily_gift(%User{} = user) do
    if daily_gift_cooldown_active?(user) do
      {:error, :cooldown}
    else
      insert_daily_gift_ledger(user)
    end
  end

  defp daily_gift_cooldown_active?(%User{} = user) do
    me_file_id = user.me_file.id
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -24 * 3600, :second)

    query =
      from e in LedgerEntry,
        join: h in LedgerHeader,
        on: e.ledger_header_id == h.id,
        where: h.me_file_id == ^me_file_id,
        where: e.meta_1 == ^@daily_gift_meta,
        where: e.created_at > ^cutoff

    Repo.exists?(query)
  end

  defp insert_daily_gift_ledger(%User{} = user) do
    Repo.transaction(fn ->
      ledger_header = user.me_file.ledger_header
      amount = @daily_gift_amount

      new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), amount)

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: "Daily gift",
        meta_1: @daily_gift_meta
      }
      |> Repo.insert!()
    end)
    |> case do
      {:ok, _} -> {:ok, :credited}
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Starter (Welcome Gift) credit -------------------------------------

  @welcome_gift_meta "Welcome Gift"
  @welcome_gift_description "QADABRA - Welcome Gift"
  @default_starter_credit "2.00"

  @doc """
  The configured starter wallet credit amount, read from the
  `starter_wallet_credit_amount` global variable (default `$2.00`).
  """
  def starter_credit_amount do
    Qlarius.System.get_global_variable("starter_wallet_credit_amount", @default_starter_credit)
    |> Decimal.new()
  end

  @doc """
  Credits a newly created wallet with the configured starter ("Welcome Gift")
  amount as its first ledger entry.

  Idempotent: a no-op when a Welcome Gift entry already exists for the header or
  when the configured amount is zero. Accepts an explicit `repo` so it can run
  inside the registration `Ecto.Multi` transaction.
  """
  def create_starter_credit(%LedgerHeader{} = ledger_header, repo \\ Repo) do
    amount = starter_credit_amount()

    cond do
      Decimal.compare(amount, Decimal.new(0)) != :gt ->
        {:ok, :skipped}

      welcome_gift_exists?(ledger_header, repo) ->
        {:ok, :skipped}

      true ->
        new_balance = Decimal.add(ledger_header.balance || Decimal.new(0), amount)

        entry =
          %LedgerEntry{
            ledger_header_id: ledger_header.id,
            amt: amount,
            running_balance: new_balance,
            description: @welcome_gift_description,
            meta_1: @welcome_gift_meta
          }
          |> repo.insert!()

        ledger_header
        |> Ecto.Changeset.change(balance: new_balance)
        |> repo.update!()

        {:ok, entry}
    end
  end

  defp welcome_gift_exists?(%LedgerHeader{id: id}, repo) do
    repo.exists?(
      from e in LedgerEntry,
        where: e.ledger_header_id == ^id and e.meta_1 == ^@welcome_gift_meta
    )
  end

  # --- Content gift ledger writers ---------------------------------------
  #
  # All bang variants insert a single ledger entry and update the header
  # balance. They do NOT open their own transaction; callers compose them inside
  # one (e.g. `ContentSharing.create_gift/2`, `redeem_gift/2`, expiration).

  @will_call_gift_meta "Tiqit Gift Purchase (Will Call)"
  @will_call_reversal_meta "Will Call Gift Reversal"
  @media_gift_credit_description "TIQIT GIFT CREDIT"
  @media_gift_credit_meta "Friend gift credit"

  @doc "Reversible sender debit recorded when a will-call gift is created."
  def create_will_call_debit!(%LedgerHeader{} = header, amount, description) do
    insert_ledger_entry!(header, Decimal.negate(amount), description, @will_call_gift_meta)
  end

  @doc "Compensating sender credit when an unclaimed will-call gift expires."
  def create_will_call_reversal!(%LedgerHeader{} = header, amount, description) do
    insert_ledger_entry!(header, amount, description, @will_call_reversal_meta)
  end

  @doc """
  Restricted recipient credit at gift claim. Visible in ledger history but
  immediately consumed by the matching Tiqit purchase in the same transaction,
  so it never becomes independently spendable.
  """
  def create_gift_passthrough_credit!(%LedgerHeader{} = header, amount) do
    insert_ledger_entry!(header, amount, @media_gift_credit_description, @media_gift_credit_meta)
  end

  @doc "Loads a me_file's ledger header by me_file id (nil if none)."
  def get_me_file_ledger_header_by_id(me_file_id) do
    Repo.get_by(LedgerHeader, me_file_id: me_file_id)
  end

  defp insert_ledger_entry!(%LedgerHeader{} = header, signed_amt, description, meta_1) do
    new_balance = Decimal.add(header.balance || Decimal.new(0), signed_amt)

    entry =
      %LedgerEntry{
        ledger_header_id: header.id,
        amt: signed_amt,
        running_balance: new_balance,
        description: description,
        meta_1: meta_1
      }
      |> Repo.insert!()

    header
    |> Ecto.Changeset.change(balance: new_balance)
    |> Repo.update!()

    entry
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

  def get_or_create_creator_ledger_header(%Qlarius.Creators.Creator{} = creator) do
    case Repo.get_by(LedgerHeader, creator_id: creator.id) do
      nil ->
        %LedgerHeader{}
        |> LedgerHeader.changeset(%{
          description: "Creator: #{creator.name}",
          balance: Decimal.new("0.00"),
          balance_payable: Decimal.new("0.00"),
          creator_id: creator.id
        })
        |> Repo.insert!()

      ledger_header ->
        ledger_header
    end
  end

  @doc """
  Gets or creates a ledger header for a recipient.
  """
  def get_or_create_recipient_ledger_header(%Recipient{} = recipient) do
    case Repo.get_by(LedgerHeader, recipient_id: recipient.id) do
      nil ->
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
  Creates a ledger header for a campaign.
  """
  def create_campaign_ledger_header(%Campaign{} = campaign, marketer_id) do
    %LedgerHeader{}
    |> LedgerHeader.changeset(%{
      description: "Campaign: #{campaign.title}",
      balance: Decimal.new("0.00"),
      balance_payable: Decimal.new("0.00"),
      campaign_id: campaign.id,
      marketer_id: marketer_id
    })
    |> Repo.insert!()
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
      description: String.upcase(ledger_event.to_ledger.recipient.name),
      meta_1: "Tip/Donation"
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
      description: "InstaTip from #{ledger_event.requested_by_user.alias}",
      meta_1: "Tip/Donation"
    })
    |> Repo.insert!()

    # Broadcast balance update
    MeFileStatsBroadcaster.broadcast_balance_updated(
      ledger_event.from_ledger.me_file_id,
      new_from_balance
    )
  end

  defp phase_description_to_meta_1(phase_desc) when is_binary(phase_desc) do
    cond do
      String.starts_with?(phase_desc, "Banner") -> "Banner Tap"
      String.starts_with?(phase_desc, "Text/Jump") -> "Text/Jump"
      String.contains?(phase_desc, "Video") -> "Video Ad"
      String.contains?(phase_desc, "Referral") -> "Referral Bonus"
      true -> nil
    end
  end

  defp phase_description_to_meta_1(_), do: nil
end
