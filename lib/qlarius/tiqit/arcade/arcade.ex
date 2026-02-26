defmodule Qlarius.Tiqit.Arcade.Arcade do
  import Ecto.Query

  alias Qlarius.YouData.MeFiles.MeFile
  alias Qlarius.Accounts.Scope
  alias Qlarius.System
  alias Qlarius.Tiqit.Arcade.Catalog
  alias Qlarius.Tiqit.Arcade.ConsumerCreatorUndoCount
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.ContentPiece
  alias Qlarius.Tiqit.Arcade.Tiqit
  alias Qlarius.Tiqit.Arcade.TiqitClass
  alias Qlarius.Wallets
  alias Qlarius.Wallets.LedgerEntry
  alias Qlarius.Wallets.LedgerHeader
  alias Qlarius.Repo

  def get_valid_tiqit(%Scope{} = scope, %ContentPiece{} = piece) do
    now = DateTime.utc_now()

    piece = Repo.preload(piece, :content_group)

    query =
      from t in Tiqit,
        join: tc in assoc(t, :tiqit_class),
        join: u in assoc(t, :user),
        where:
          tc.content_piece_id == ^piece.id or
            tc.content_group_id == ^piece.content_group_id or
            tc.catalog_id == ^piece.content_group.catalog_id,
        where: u.id == ^scope.user.id,
        where: is_nil(t.expires_at) or t.expires_at > ^now,
        limit: 1

    Repo.one(query)
  end

  def has_valid_tiqit?(%Scope{} = scope, %ContentPiece{} = piece) do
    !!get_valid_tiqit(scope, piece)
  end

  def list_content_groups do
    Repo.all(from g in ContentGroup, order_by: [asc: g.title])
  end

  def get_content_group!(id) do
    ContentGroup
    |> Repo.get!(id)
    |> Repo.preload([
      :tiqit_classes,
      catalog: [:tiqit_classes, :creator, content_groups: :content_pieces],
      content_pieces: :tiqit_classes
    ])
  end

  def list_pieces_in_content_group(%ContentGroup{} = group) do
    Repo.all(
      from c in ContentPiece,
        where: c.group_id == ^group.id,
        order_by: [desc: c.inserted_at],
        limit: 5,
        preload: [tiqit_classes: ^from(t in TiqitClass, order_by: t.price)]
    )
  end

  def get_tiqit_class_for_piece!(class_id, %ContentPiece{} = piece, %ContentGroup{} = group) do
    class = TiqitClass |> Repo.get!(class_id)

    # for security, validate the tiqit belongs to a piece/group/catalog
    # in the current arcade
    classes = piece.tiqit_classes ++ group.tiqit_classes ++ group.catalog.tiqit_classes

    id = String.to_integer(class_id)

    if Enum.find(classes, &(&1.id == id)) do
      class
    else
      raise "invalid tiqit class"
    end
  end

  # TODO use Creators.get_content_piece! instead? ... maybe
  def get_content_piece!(id) do
    ContentPiece |> Repo.get!(id) |> Repo.preload([content_group: :catalog, tiqit_classes: []])
  end

  def create_content(attrs \\ %{}) do
    %ContentPiece{}
    |> ContentPiece.changeset(attrs)
    |> Repo.insert()
  end

  def update_content(%ContentPiece{} = content, attrs) do
    content
    |> ContentPiece.changeset(attrs)
    |> Repo.update()
  end

  def change_content(%ContentPiece{} = content, attrs \\ %{}) do
    ContentPiece.changeset(content, attrs)
  end

  # Added missing function that was being called from TiqitController
  def list_user_tiqits(user) do
    Repo.all(
      from t in Tiqit,
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        order_by: [desc: t.purchased_at],
        preload: [:tiqit_class]
    )
  end

  def purchase_tiqit(%Scope{} = scope, %TiqitClass{} = tiqit_class, opts \\ []) do
    %{user: user} = scope
    tiqit_up_credit = Keyword.get(opts, :tiqit_up_credit, Decimal.new(0))
    purchased_at = DateTime.utc_now()

    tiqit_class =
      Repo.preload(tiqit_class, [
        :content_piece,
        :content_group,
        :catalog,
        content_piece: [content_group: [catalog: :creator]],
        content_group: [catalog: :creator],
        catalog: :creator
      ])

    expires_at =
      if tiqit_class.duration_hours do
        DateTime.add(purchased_at, tiqit_class.duration_hours, :hour)
      end

    has_credit = Decimal.compare(tiqit_up_credit, Decimal.new(0)) == :gt
    net_price = Decimal.max(Decimal.new(0), Decimal.sub(tiqit_class.price, tiqit_up_credit))

    Repo.transaction(fn ->
      ledger_header = %LedgerHeader{} = Wallets.get_me_file_ledger_header(user.me_file)
      me_file = %MeFile{} = user.me_file

      amount = Decimal.negate(net_price)
      new_balance = Decimal.add(ledger_header.balance, amount)

      {:ok, tiqit} =
        %Tiqit{me_file: me_file, tiqit_class: tiqit_class}
        |> Tiqit.changeset(%{purchased_at: purchased_at, expires_at: expires_at})
        |> Repo.insert()

      duration_label = format_duration(tiqit_class.duration_hours)
      content_title = tiqit_content_title(tiqit_class)

      {consumer_desc, consumer_meta} =
        if has_credit do
          is_free = Decimal.compare(net_price, Decimal.new(0)) != :gt

          desc =
            if is_free,
              do: "Tiqit Up: #{content_title} (#{duration_label}) -- Free (covered by credits)",
              else: "Tiqit Up: #{content_title} (#{duration_label}) -- $#{tiqit_up_credit} credited"

          {desc, "Tiqit Up"}
        else
          {"Tiqit purchase: #{content_title} (#{duration_label})", "Tiqit Purchase"}
        end

      %LedgerEntry{
        ledger_header_id: ledger_header.id,
        amt: amount,
        running_balance: new_balance,
        description: consumer_desc,
        meta_1: consumer_meta,
        tiqit_id: tiqit.id
      }
      |> Repo.insert!()

      ledger_header
      |> Ecto.Changeset.change(balance: new_balance)
      |> Repo.update!()

      creator = tiqit_class_creator(tiqit_class)

      if creator do
        creator_ledger = Wallets.get_or_create_creator_ledger_header(creator)
        creator_new_balance = Decimal.add(creator_ledger.balance, net_price)

        creator_desc =
          if has_credit,
            do: "Tiqit Up sale: #{content_title} (#{duration_label}) -- $#{tiqit_up_credit} credited to consumer",
            else: "Tiqit sale: #{content_title} (#{duration_label})"

        %LedgerEntry{
          ledger_header_id: creator_ledger.id,
          amt: net_price,
          running_balance: creator_new_balance,
          description: creator_desc,
          meta_1: "Tiqit Sale",
          tiqit_id: tiqit.id
        }
        |> Repo.insert!()

        creator_ledger
        |> Ecto.Changeset.change(balance: creator_new_balance)
        |> Repo.update!()
      end

      tiqit
    end)

    :ok
  end

  defp tiqit_class_creator(%TiqitClass{} = tc) do
    cond do
      tc.content_piece && tc.content_piece.content_group ->
        tc.content_piece.content_group.catalog.creator

      tc.content_group && tc.content_group.catalog ->
        tc.content_group.catalog.creator

      tc.catalog ->
        tc.catalog.creator

      true ->
        nil
    end
  end

  defp tiqit_content_title(%TiqitClass{} = tc) do
    cond do
      tc.content_piece -> tc.content_piece.title
      tc.content_group -> tc.content_group.title
      tc.catalog -> tc.catalog.name
      true -> "Unknown"
    end
  end

  defp format_duration(nil), do: "lifetime"
  defp format_duration(hours) when hours < 24, do: "#{hours}h"
  defp format_duration(24), do: "24h"
  defp format_duration(hours) when rem(hours, 24) == 0, do: "#{div(hours, 24)} days"
  defp format_duration(hours), do: "#{hours}h"

  def write_default_catalog_tiqit_classes(%Catalog{} = catalog) do
    default_tiqit_class_grid()
    |> Enum.each(fn duration_map ->
      [{duration, prices}] = Map.to_list(duration_map)
      upsert_tiqit_class(duration, prices.catalog, catalog_id: catalog.id)
    end)
  end

  def write_default_group_tiqit_classes(%ContentGroup{} = group) do
    default_tiqit_class_grid()
    |> Enum.each(fn duration_map ->
      [{duration, prices}] = Map.to_list(duration_map)
      upsert_tiqit_class(duration, prices.group, content_group_id: group.id)
    end)
  end

  def write_default_piece_tiqit_classes(%ContentPiece{} = piece) do
    default_tiqit_class_grid()
    |> Enum.each(fn duration_map ->
      [{duration, prices}] = Map.to_list(duration_map)
      upsert_tiqit_class(duration, prices.piece, content_piece_id: piece.id)
    end)
  end

  # Helper function to upsert (insert or update) tiqit classes
  defp upsert_tiqit_class(duration_hours, price, query_params) do
    case Repo.get_by(TiqitClass, [duration_hours: duration_hours] ++ query_params) do
      nil ->
        # Create new tiqit class
        struct(TiqitClass, [duration_hours: duration_hours, price: price] ++ query_params)
        |> Repo.insert!()

      existing_class ->
        # Update existing tiqit class price
        existing_class
        |> TiqitClass.changeset(%{price: price})
        |> Repo.update!()
    end
  end

  # --- Tiqit Up credit ---

  def calculate_tiqit_up_credit(%Scope{user: user}, %ContentGroup{} = group) do
    group = Repo.preload(group, catalog: [])
    catalog = group.catalog

    if catalog.tiqit_up_enabled do
      now = DateTime.utc_now()

      from(t in Tiqit,
        join: tc in assoc(t, :tiqit_class),
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
        where: is_nil(t.expires_at) or t.expires_at > ^now,
        where: tc.content_piece_id in subquery(
          from cp in ContentPiece,
            where: cp.content_group_id == ^group.id,
            select: cp.id
        ),
        select: sum(tc.price)
      )
      |> Repo.one()
      |> case do
        nil -> Decimal.new(0)
        total -> total
      end
    else
      Decimal.new(0)
    end
  end

  def calculate_tiqit_up_credit(%Scope{user: user}, %Catalog{} = catalog) do
    if catalog.tiqit_up_enabled do
      now = DateTime.utc_now()

      group_ids =
        from(cg in ContentGroup, where: cg.catalog_id == ^catalog.id, select: cg.id)

      piece_ids =
        from(cp in ContentPiece, where: cp.group_id in subquery(group_ids), select: cp.id)

      from(t in Tiqit,
        join: tc in assoc(t, :tiqit_class),
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
        where: is_nil(t.expires_at) or t.expires_at > ^now,
        where:
          tc.content_piece_id in subquery(piece_ids) or
            tc.content_group_id in subquery(group_ids),
        select: sum(tc.price)
      )
      |> Repo.one()
      |> case do
        nil -> Decimal.new(0)
        total -> total
      end
    else
      Decimal.new(0)
    end
  end

  def check_tiqit_up_nudge(%Scope{} = scope, %ContentGroup{} = group) do
    group = Repo.preload(group, [:tiqit_classes, catalog: []])
    catalog = group.catalog

    if catalog.tiqit_up_enabled and Enum.any?(group.tiqit_classes) do
      credit = calculate_tiqit_up_credit(scope, group)
      cheapest_group_price = group.tiqit_classes |> Enum.map(& &1.price) |> Enum.min()

      if Decimal.compare(credit, cheapest_group_price) != :lt do
        {:nudge, credit, cheapest_group_price}
      else
        :no_nudge
      end
    else
      :no_nudge
    end
  end

  # --- Tiqit state helpers ---

  def tiqit_status(%Tiqit{} = tiqit) do
    now = DateTime.utc_now()

    cond do
      tiqit.undone_at != nil -> :undone
      tiqit.disconnected_at != nil -> :fleeted
      expired?(tiqit, now) -> :expired
      true -> :active
    end
  end

  defp expired?(%Tiqit{expires_at: nil}, _now), do: false
  defp expired?(%Tiqit{expires_at: expires_at}, now), do: DateTime.compare(expires_at, now) != :gt

  def time_remaining(%Tiqit{expires_at: nil}), do: :lifetime

  def time_remaining(%Tiqit{expires_at: expires_at}) do
    diff = DateTime.diff(expires_at, DateTime.utc_now(), :second)
    if diff > 0, do: diff, else: 0
  end

  def time_until_fleet(%Tiqit{expires_at: nil}, _fleet_after_hours), do: :never

  def time_until_fleet(%Tiqit{} = tiqit, fleet_after_hours) do
    fleet_at = DateTime.add(tiqit.expires_at, fleet_after_hours, :hour)
    diff = DateTime.diff(fleet_at, DateTime.utc_now(), :second)
    if diff > 0, do: diff, else: 0
  end

  def undo_available?(%Tiqit{} = tiqit) do
    undo_window = System.get_global_variable_int("tiqit_undo_window_hours", 2)
    deadline = DateTime.add(tiqit.purchased_at, undo_window, :hour)

    is_nil(tiqit.undone_at) and
      is_nil(tiqit.disconnected_at) and
      not is_nil(tiqit.me_file_id) and
      DateTime.compare(DateTime.utc_now(), deadline) == :lt
  end

  def get_undo_context(%Scope{user: user}, %Tiqit{} = tiqit) do
    tiqit =
      Repo.preload(tiqit,
        tiqit_class: [
          content_piece: [content_group: [catalog: :creator]],
          content_group: [catalog: :creator],
          catalog: :creator
        ]
      )

    creator = tiqit_class_creator(tiqit.tiqit_class)
    catalog = tiqit_class_catalog(tiqit.tiqit_class)
    undo_limit = if catalog, do: catalog.tiqit_undo_limit
    undos_used = if creator && undo_limit, do: get_undo_count(user.me_file.id, creator.id), else: 0
    undos_remaining = if undo_limit, do: undo_limit - undos_used

    %{
      tiqit_id: tiqit.id,
      creator_name: if(creator, do: creator.name, else: "Unknown"),
      undo_limit: undo_limit,
      undos_used: undos_used,
      undos_remaining: undos_remaining,
      limited?: undo_limit != nil
    }
  end

  # --- Query functions ---

  def count_active_tiqits(%{id: user_id}) when is_integer(user_id) do
    now = DateTime.utc_now()

    from(t in Tiqit,
      join: u in assoc(t, :user),
      where: u.id == ^user_id,
      where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
      where: is_nil(t.expires_at) or t.expires_at > ^now
    )
    |> Repo.aggregate(:count)
  end

  def count_active_tiqits(%Scope{user: user}) do
    now = DateTime.utc_now()

    from(t in Tiqit,
      join: u in assoc(t, :user),
      where: u.id == ^user.id,
      where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
      where: is_nil(t.expires_at) or t.expires_at > ^now
    )
    |> Repo.aggregate(:count)
  end

  def count_expired_tiqits(%Scope{user: user}) do
    now = DateTime.utc_now()

    from(t in Tiqit,
      join: u in assoc(t, :user),
      where: u.id == ^user.id,
      where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
      where: not is_nil(t.expires_at) and t.expires_at <= ^now
    )
    |> Repo.aggregate(:count)
  end

  def count_total_purchases(%Scope{user: user}) do
    me_file = user.me_file
    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    if ledger_header do
      from(e in LedgerEntry,
        where: e.ledger_header_id == ^ledger_header.id,
        where: e.meta_1 in ["Tiqit Purchase", "Tiqit Up"]
      )
      |> Repo.aggregate(:count)
    else
      0
    end
  end

  def count_fleeted_tiqits(%Scope{user: user}) do
    me_file = user.me_file
    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    if ledger_header do
      total_purchases =
        from(e in LedgerEntry,
          where: e.ledger_header_id == ^ledger_header.id,
          where: e.meta_1 in ["Tiqit Purchase", "Tiqit Up"]
        )
        |> Repo.aggregate(:count)

      undone_count =
        from(e in LedgerEntry,
          where: e.ledger_header_id == ^ledger_header.id,
          where: e.meta_1 == "Tiqit Undo"
        )
        |> Repo.aggregate(:count)

      still_linked =
        from(t in Tiqit,
          where: t.me_file_id == ^me_file.id,
          where: is_nil(t.disconnected_at) and is_nil(t.undone_at)
        )
        |> Repo.aggregate(:count)

      max(total_purchases - undone_count - still_linked, 0)
    else
      0
    end
  end

  def count_undone_tiqits(%Scope{user: user}) do
    me_file = user.me_file
    ledger_header = Repo.get_by(LedgerHeader, me_file_id: me_file.id)

    if ledger_header do
      from(e in LedgerEntry,
        where: e.ledger_header_id == ^ledger_header.id,
        where: e.meta_1 == "Tiqit Undo"
      )
      |> Repo.aggregate(:count)
    else
      0
    end
  end

  def list_tiqits_by_status(%Scope{user: user}, status) do
    now = DateTime.utc_now()

    base =
      from t in Tiqit,
        join: u in assoc(t, :user),
        where: u.id == ^user.id,
        order_by: [desc: t.purchased_at],
        preload: [
          tiqit_class: [
            content_piece: [content_group: [catalog: :creator]],
            content_group: [catalog: :creator],
            catalog: :creator
          ]
        ]

    query =
      case status do
        :active ->
          from t in base,
            where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
            where: is_nil(t.expires_at) or t.expires_at > ^now

        :expired ->
          from t in base,
            where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
            where: not is_nil(t.expires_at) and t.expires_at <= ^now,
            where: t.preserved == false

        :preserved ->
          from t in base,
            where: is_nil(t.disconnected_at) and is_nil(t.undone_at),
            where: t.preserved == true

        :fleeted ->
          from t in base,
            where: not is_nil(t.disconnected_at) and is_nil(t.undone_at)

        :undone ->
          from t in base,
            where: not is_nil(t.undone_at)

        _ ->
          base
      end

    Repo.all(query)
  end

  # --- Tiqit actions ---

  def fleet_tiqit!(%Tiqit{} = tiqit) do
    Repo.transaction(fn ->
      sanitize_consumer_ledger_entries(tiqit)

      tiqit
      |> Tiqit.changeset(%{disconnected_at: DateTime.utc_now(), me_file_id: nil})
      |> Repo.update!()

      from(e in LedgerEntry, where: e.tiqit_id == ^tiqit.id)
      |> Repo.update_all(set: [tiqit_id: nil])
    end)
  end

  def preserve_tiqit(%Tiqit{} = tiqit, preserved) when is_boolean(preserved) do
    tiqit
    |> Tiqit.changeset(%{preserved: preserved})
    |> Repo.update()
  end

  def undo_tiqit!(%Scope{user: user} = _scope, %Tiqit{} = tiqit) do
    tiqit =
      Repo.preload(tiqit,
        tiqit_class: [
          :content_piece,
          :content_group,
          :catalog,
          content_piece: [content_group: [catalog: :creator]],
          content_group: [catalog: :creator],
          catalog: :creator
        ]
      )

    undo_window = System.get_global_variable_int("tiqit_undo_window_hours", 2)
    deadline = DateTime.add(tiqit.purchased_at, undo_window, :hour)
    now = DateTime.utc_now()

    cond do
      tiqit.undone_at != nil ->
        {:error, :already_undone}

      tiqit.disconnected_at != nil ->
        {:error, :already_fleeted}

      is_nil(tiqit.me_file_id) ->
        {:error, :already_fleeted}

      DateTime.compare(now, deadline) != :lt ->
        {:error, :undo_window_expired}

      true ->
        creator = tiqit_class_creator(tiqit.tiqit_class)
        catalog = tiqit_class_catalog(tiqit.tiqit_class)

        with :ok <- check_undo_limit(user.me_file, creator, catalog) do
          Repo.transaction(fn ->
            duration_label = format_duration(tiqit.tiqit_class.duration_hours)
            content_title = tiqit_content_title(tiqit.tiqit_class)

            # Reverse consumer ledger
            consumer_ledger = Wallets.get_me_file_ledger_header(user.me_file)
            refund_amount = tiqit.tiqit_class.price
            new_consumer_balance = Decimal.add(consumer_ledger.balance, refund_amount)

            %LedgerEntry{
              ledger_header_id: consumer_ledger.id,
              amt: refund_amount,
              running_balance: new_consumer_balance,
              description: "Tiqit undo (refund)",
              meta_1: "Tiqit Undo"
            }
            |> Repo.insert!()

            consumer_ledger
            |> Ecto.Changeset.change(balance: new_consumer_balance)
            |> Repo.update!()

            # Reverse creator ledger
            if creator do
              creator_ledger = Wallets.get_or_create_creator_ledger_header(creator)
              creator_debit = Decimal.negate(refund_amount)
              new_creator_balance = Decimal.add(creator_ledger.balance, creator_debit)

              %LedgerEntry{
                ledger_header_id: creator_ledger.id,
                amt: creator_debit,
                running_balance: new_creator_balance,
                description: "Tiqit undo: #{content_title} (#{duration_label})",
                meta_1: "Tiqit Undo"
              }
              |> Repo.insert!()

              creator_ledger
              |> Ecto.Changeset.change(balance: new_creator_balance)
              |> Repo.update!()
            end

            # Sanitize consumer's original purchase entry before unlinking
            sanitize_consumer_ledger_entries(tiqit)

            # Mark tiqit as undone + fleet
            tiqit
            |> Tiqit.changeset(%{
              undone_at: now,
              disconnected_at: now,
              me_file_id: nil
            })
            |> Repo.update!()

            # Unlink ledger entries
            from(e in LedgerEntry, where: e.tiqit_id == ^tiqit.id)
            |> Repo.update_all(set: [tiqit_id: nil])

            # Increment undo counter only if creator has finite limit
            if catalog && catalog.tiqit_undo_limit do
              increment_undo_count(user.me_file.id, creator.id)
            end

            :ok
          end)
        end
    end
  end

  defp sanitize_consumer_ledger_entries(%Tiqit{} = tiqit) do
    if tiqit.me_file_id do
      consumer_ledger = Repo.get_by(LedgerHeader, me_file_id: tiqit.me_file_id)

      if consumer_ledger do
        from(e in LedgerEntry,
          where: e.tiqit_id == ^tiqit.id,
          where: e.ledger_header_id == ^consumer_ledger.id
        )
        |> Repo.update_all(set: [description: "Tiqit purchase (fleeted)"])
      end
    end
  end

  defp check_undo_limit(me_file, creator, catalog) do
    cond do
      is_nil(catalog) or is_nil(catalog.tiqit_undo_limit) ->
        :ok

      true ->
        count = get_undo_count(me_file.id, creator.id)

        if count < catalog.tiqit_undo_limit do
          :ok
        else
          {:error, :undo_limit_reached}
        end
    end
  end

  defp get_undo_count(me_file_id, creator_id) do
    case Repo.get_by(ConsumerCreatorUndoCount,
           me_file_id: me_file_id,
           creator_id: creator_id
         ) do
      nil -> 0
      record -> record.count
    end
  end

  defp increment_undo_count(me_file_id, creator_id) do
    case Repo.get_by(ConsumerCreatorUndoCount,
           me_file_id: me_file_id,
           creator_id: creator_id
         ) do
      nil ->
        %ConsumerCreatorUndoCount{}
        |> ConsumerCreatorUndoCount.changeset(%{
          me_file_id: me_file_id,
          creator_id: creator_id,
          count: 1
        })
        |> Repo.insert!()

      record ->
        record
        |> ConsumerCreatorUndoCount.changeset(%{count: record.count + 1})
        |> Repo.update!()
    end
  end

  defp tiqit_class_catalog(%TiqitClass{} = tc) do
    cond do
      tc.content_piece && tc.content_piece.content_group ->
        tc.content_piece.content_group.catalog

      tc.content_group && tc.content_group.catalog ->
        tc.content_group.catalog

      tc.catalog ->
        tc.catalog

      true ->
        nil
    end
  end

  defp default_tiqit_class_grid() do
    [
      %{3 => %{catalog: 0.50, group: 0.25, piece: 0.10}},
      %{24 => %{catalog: 0.75, group: 0.50, piece: 0.25}},
      %{168 => %{catalog: 1.50, group: 0.75, piece: 0.50}},
      %{720 => %{catalog: 3.00, group: 1.00, piece: 0.75}}
    ]
  end
end
