defmodule Qlarius.Maintenance.CleanupOrphanedMarketerRecords do
  @moduledoc """
  Cleans up orphaned records where marketer_id references a non-existent marketer.

  This includes:
  - Campaigns
  - Offers (via campaigns)
  - Bids (via campaigns)
  - Targets
  - TargetBands (via targets)
  - TraitGroups
  - MediaPieces
  - MediaSequences
  - MediaRuns

  Does NOT delete:
  - Ledger entries
  - AdEvents
  - Any financial records

  Usage:
    # Step 1: Diagnose to see what will be deleted
    Qlarius.Maintenance.CleanupOrphanedMarketerRecords.diagnose()

    # Step 2: Dry run to preview (doesn't delete anything)
    Qlarius.Maintenance.CleanupOrphanedMarketerRecords.run(dry_run: true)

    # Step 3: Actually delete (requires explicit flag)
    Qlarius.Maintenance.CleanupOrphanedMarketerRecords.run(execute: true)
  """

  import Ecto.Query
  require Logger
  alias Qlarius.Repo
  alias Qlarius.Accounts.Marketer
  alias Qlarius.Sponster.{Offer, AdEvent}

  alias Qlarius.Sponster.Campaigns.{
    Campaign,
    Bid,
    Target,
    TargetBand,
    TraitGroup,
    MediaSequence,
    MediaRun
  }

  alias Qlarius.Sponster.Ads.MediaPiece

  @doc """
  Diagnoses orphaned records without making any changes.
  Shows counts and sample records for each table.
  """
  def diagnose do
    IO.puts("\n=== Diagnosing Orphaned Marketer Records ===\n")

    orphaned_marketer_ids = find_orphaned_marketer_ids()

    if Enum.empty?(orphaned_marketer_ids) do
      IO.puts("✅ No orphaned marketer IDs found!")
      IO.puts("All records reference existing marketers.\n")
      {:ok, :no_orphans}
    else
      IO.puts("Found references to #{length(orphaned_marketer_ids)} non-existent marketer(s):")

      Enum.each(orphaned_marketer_ids, fn id ->
        IO.puts("  - Marketer ID: #{id}")
      end)

      IO.puts("")

      counts = count_orphaned_records(orphaned_marketer_ids)
      total = Map.values(counts) |> Enum.sum()

      IO.puts("=== Records to be deleted ===\n")
      IO.puts("Offers:        #{counts.offers}")
      IO.puts("Bids:          #{counts.bids}")
      IO.puts("Campaigns:     #{counts.campaigns}")
      IO.puts("MediaRuns:     #{counts.media_runs}")
      IO.puts("TargetBands:   #{counts.target_bands}")
      IO.puts("Targets:       #{counts.targets}")
      IO.puts("TraitGroups:   #{counts.trait_groups}")
      IO.puts("MediaPieces:   #{counts.media_pieces}")
      IO.puts("MediaSequences: #{counts.media_sequences}")
      IO.puts("─" |> String.duplicate(40))
      IO.puts("TOTAL:         #{total}\n")

      if total > 0 do
        show_sample_records(orphaned_marketer_ids)
      end

      {:ok, counts}
    end
  end

  @doc """
  Runs the cleanup process.

  Options:
    - dry_run: true - Show what would be deleted without actually deleting (default: false)
    - execute: true - Actually perform the deletion (required if not dry_run)
    - batch_size: integer - Number of records to delete per batch (default: 100)
  """
  def run(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    execute = Keyword.get(opts, :execute, false)
    batch_size = Keyword.get(opts, :batch_size, 100)

    unless dry_run or execute do
      IO.puts("\n⚠️  ERROR: You must specify either dry_run: true or execute: true")
      IO.puts("Usage:")
      IO.puts("  Qlarius.Maintenance.CleanupOrphanedMarketerRecords.run(dry_run: true)")
      IO.puts("  Qlarius.Maintenance.CleanupOrphanedMarketerRecords.run(execute: true)\n")
      {:error, :missing_flag}
    else
      mode = if dry_run, do: "DRY RUN", else: "EXECUTION"
      IO.puts("\n=== Cleanup Orphaned Records (#{mode}) ===\n")

      orphaned_marketer_ids = find_orphaned_marketer_ids()

      if Enum.empty?(orphaned_marketer_ids) do
        IO.puts("✅ No orphaned records to clean up!\n")
        {:ok, :no_orphans}
      else
        IO.puts("Processing records for #{length(orphaned_marketer_ids)} orphaned marketer(s)\n")

        if dry_run do
          counts = count_orphaned_records(orphaned_marketer_ids)
          IO.puts("Would delete:")
          print_summary(counts)
          {:ok, counts}
        else
          IO.puts("⚠️  WARNING: This will permanently delete records!")
          IO.puts("Press Ctrl+C within 5 seconds to cancel...\n")
          Process.sleep(5000)

          result = delete_orphaned_records(orphaned_marketer_ids, batch_size)
          IO.puts("\n=== Cleanup Complete ===\n")
          print_summary(result)
          {:ok, result}
        end
      end
    end
  end

  @doc """
  Verifies that all orphaned records have been cleaned up.
  """
  def verify do
    IO.puts("\n=== Verifying Cleanup ===\n")
    orphaned_marketer_ids = find_orphaned_marketer_ids()

    if Enum.empty?(orphaned_marketer_ids) do
      IO.puts("✅ Verification successful!")
      IO.puts("No orphaned marketer references found.\n")
      {:ok, :verified}
    else
      IO.puts("⚠️  Warning: Still found #{length(orphaned_marketer_ids)} orphaned marketer ID(s)")
      counts = count_orphaned_records(orphaned_marketer_ids)
      print_summary(counts)
      {:error, :orphans_remain, counts}
    end
  end

  @doc """
  Returns true if there are orphaned records, false otherwise.
  Useful for conditional checks without output.
  """
  def verify? do
    orphaned_marketer_ids = find_orphaned_marketer_ids()
    not Enum.empty?(orphaned_marketer_ids)
  end

  # Private Functions

  defp find_orphaned_marketer_ids do
    tables_with_marketer_id = [
      {Campaign, :marketer_id},
      {Target, :marketer_id},
      {TraitGroup, :marketer_id},
      {MediaPiece, :marketer_id},
      {MediaSequence, :marketer_id},
      {MediaRun, :marketer_id}
    ]

    tables_with_marketer_id
    |> Enum.flat_map(fn {schema, field} ->
      from(t in schema,
        select: field(t, ^field),
        distinct: true,
        where: not is_nil(field(t, ^field))
      )
      |> Repo.all()
    end)
    |> Enum.uniq()
    |> Enum.reject(fn marketer_id ->
      Repo.exists?(from m in Marketer, where: m.id == ^marketer_id)
    end)
    |> Enum.sort()
  end

  defp count_orphaned_records(orphaned_marketer_ids) do
    orphaned_campaign_ids = get_orphaned_campaign_ids(orphaned_marketer_ids)
    orphaned_target_ids = get_orphaned_target_ids(orphaned_marketer_ids)
    orphaned_media_sequence_ids = get_orphaned_media_sequence_ids(orphaned_marketer_ids)
    orphaned_media_run_ids = get_orphaned_media_run_ids(orphaned_marketer_ids)

    %{
      offers: count_offers(orphaned_campaign_ids, orphaned_media_run_ids),
      bids: count_bids(orphaned_campaign_ids),
      campaigns: length(orphaned_campaign_ids),
      media_runs: length(orphaned_media_run_ids),
      target_bands: count_target_bands(orphaned_target_ids),
      targets: length(orphaned_target_ids),
      trait_groups: count_trait_groups(orphaned_marketer_ids),
      media_pieces: count_media_pieces(orphaned_marketer_ids),
      media_sequences: length(orphaned_media_sequence_ids)
    }
  end

  defp get_orphaned_campaign_ids(orphaned_marketer_ids) do
    from(c in Campaign, where: c.marketer_id in ^orphaned_marketer_ids, select: c.id)
    |> Repo.all()
  end

  defp get_orphaned_target_ids(orphaned_marketer_ids) do
    from(t in Target, where: t.marketer_id in ^orphaned_marketer_ids, select: t.id)
    |> Repo.all()
  end

  defp get_orphaned_media_sequence_ids(orphaned_marketer_ids) do
    from(ms in MediaSequence, where: ms.marketer_id in ^orphaned_marketer_ids, select: ms.id)
    |> Repo.all()
  end

  defp get_orphaned_media_run_ids(orphaned_marketer_ids) do
    from(mr in MediaRun, where: mr.marketer_id in ^orphaned_marketer_ids, select: mr.id)
    |> Repo.all()
  end

  defp count_offers(campaign_ids, media_run_ids) do
    from(o in Offer,
      where: o.campaign_id in ^campaign_ids or o.media_run_id in ^media_run_ids
    )
    |> Repo.aggregate(:count)
  end

  defp count_bids(campaign_ids) do
    from(b in Bid, where: b.campaign_id in ^campaign_ids)
    |> Repo.aggregate(:count)
  end

  defp count_target_bands(target_ids) do
    from(tb in TargetBand, where: tb.target_id in ^target_ids)
    |> Repo.aggregate(:count)
  end

  defp count_trait_groups(marketer_ids) do
    from(tg in TraitGroup, where: tg.marketer_id in ^marketer_ids)
    |> Repo.aggregate(:count)
  end

  defp count_media_pieces(marketer_ids) do
    from(mp in MediaPiece, where: mp.marketer_id in ^marketer_ids)
    |> Repo.aggregate(:count)
  end

  defp show_sample_records(orphaned_marketer_ids) do
    IO.puts("=== Sample Records (showing up to 3 per table) ===\n")

    orphaned_campaign_ids = get_orphaned_campaign_ids(orphaned_marketer_ids)

    if length(orphaned_campaign_ids) > 0 do
      IO.puts("--- Campaigns ---")

      from(c in Campaign,
        where: c.id in ^Enum.take(orphaned_campaign_ids, 3),
        select: %{id: c.id, title: c.title, marketer_id: c.marketer_id}
      )
      |> Repo.all()
      |> Enum.each(fn c ->
        IO.puts("  ID: #{c.id}, Title: #{c.title}, Marketer ID: #{c.marketer_id}")
      end)

      IO.puts("")
    end

    orphaned_target_ids = get_orphaned_target_ids(orphaned_marketer_ids)

    if length(orphaned_target_ids) > 0 do
      IO.puts("--- Targets ---")

      from(t in Target,
        where: t.id in ^Enum.take(orphaned_target_ids, 3),
        select: %{id: t.id, title: t.title, marketer_id: t.marketer_id}
      )
      |> Repo.all()
      |> Enum.each(fn t ->
        IO.puts("  ID: #{t.id}, Title: #{t.title}, Marketer ID: #{t.marketer_id}")
      end)

      IO.puts("")
    end

    from(tg in TraitGroup,
      where: tg.marketer_id in ^orphaned_marketer_ids,
      limit: 3,
      select: %{id: tg.id, title: tg.title, marketer_id: tg.marketer_id}
    )
    |> Repo.all()
    |> case do
      [] ->
        :ok

      trait_groups ->
        IO.puts("--- Trait Groups ---")

        Enum.each(trait_groups, fn tg ->
          IO.puts("  ID: #{tg.id}, Title: #{tg.title}, Marketer ID: #{tg.marketer_id}")
        end)

        IO.puts("")
    end
  end

  defp delete_orphaned_records(orphaned_marketer_ids, batch_size) do
    Logger.info("Starting deletion of orphaned marketer records")

    orphaned_campaign_ids = get_orphaned_campaign_ids(orphaned_marketer_ids)
    orphaned_target_ids = get_orphaned_target_ids(orphaned_marketer_ids)
    orphaned_media_sequence_ids = get_orphaned_media_sequence_ids(orphaned_marketer_ids)
    orphaned_media_run_ids = get_orphaned_media_run_ids(orphaned_marketer_ids)

    offers_deleted = delete_offers(orphaned_campaign_ids, orphaned_media_run_ids, batch_size)
    bids_deleted = delete_bids(orphaned_campaign_ids, batch_size)
    campaigns_deleted = delete_campaigns(orphaned_campaign_ids, batch_size)
    media_runs_deleted = delete_media_runs(orphaned_media_run_ids, batch_size)
    target_bands_deleted = delete_target_bands(orphaned_target_ids, batch_size)
    targets_deleted = delete_targets(orphaned_target_ids, batch_size)
    trait_groups_deleted = delete_trait_groups(orphaned_marketer_ids, batch_size)
    media_pieces_deleted = delete_media_pieces(orphaned_marketer_ids, batch_size)
    media_sequences_deleted = delete_media_sequences(orphaned_media_sequence_ids, batch_size)

    Logger.info("Deletion complete")

    %{
      offers: offers_deleted,
      bids: bids_deleted,
      campaigns: campaigns_deleted,
      media_runs: media_runs_deleted,
      target_bands: target_bands_deleted,
      targets: targets_deleted,
      trait_groups: trait_groups_deleted,
      media_pieces: media_pieces_deleted,
      media_sequences: media_sequences_deleted
    }
  end

  defp delete_offers(campaign_ids, media_run_ids, batch_size) do
    delete_in_batches(
      "Offers",
      from(o in Offer,
        where: o.campaign_id in ^campaign_ids or o.media_run_id in ^media_run_ids
      ),
      batch_size
    )
  end

  defp delete_bids(campaign_ids, batch_size) do
    delete_in_batches(
      "Bids",
      from(b in Bid, where: b.campaign_id in ^campaign_ids),
      batch_size
    )
  end

  defp delete_campaigns(campaign_ids, batch_size) do
    delete_in_batches(
      "Campaigns",
      from(c in Campaign, where: c.id in ^campaign_ids),
      batch_size
    )
  end

  defp delete_media_runs(media_run_ids, batch_size) do
    delete_in_batches(
      "MediaRuns",
      from(mr in MediaRun, where: mr.id in ^media_run_ids),
      batch_size
    )
  end

  defp delete_target_bands(target_ids, batch_size) do
    delete_in_batches(
      "TargetBands",
      from(tb in TargetBand, where: tb.target_id in ^target_ids),
      batch_size
    )
  end

  defp delete_targets(target_ids, batch_size) do
    delete_in_batches(
      "Targets",
      from(t in Target, where: t.id in ^target_ids),
      batch_size
    )
  end

  defp delete_trait_groups(marketer_ids, batch_size) do
    delete_in_batches(
      "TraitGroups",
      from(tg in TraitGroup, where: tg.marketer_id in ^marketer_ids),
      batch_size
    )
  end

  defp delete_media_pieces(marketer_ids, batch_size) do
    delete_in_batches(
      "MediaPieces",
      from(mp in MediaPiece, where: mp.marketer_id in ^marketer_ids),
      batch_size
    )
  end

  defp delete_media_sequences(media_sequence_ids, batch_size) do
    delete_in_batches(
      "MediaSequences",
      from(ms in MediaSequence, where: ms.id in ^media_sequence_ids),
      batch_size
    )
  end

  defp delete_in_batches(table_name, query, batch_size) do
    total = Repo.aggregate(query, :count)

    if total == 0 do
      IO.puts("#{table_name}: 0 records (skipped)")
      0
    else
      IO.puts("#{table_name}: Deleting #{total} records...")
      Logger.info("Deleting #{total} #{table_name} records")

      deleted_count = delete_in_batches_loop(query, batch_size, 0)

      IO.puts("#{table_name}: ✅ Deleted #{deleted_count} records")
      Logger.info("Deleted #{deleted_count} #{table_name} records")
      deleted_count
    end
  end

  defp delete_in_batches_loop(query, batch_size, total_deleted) do
    ids =
      query
      |> select([q], q.id)
      |> limit(^batch_size)
      |> Repo.all()

    case ids do
      [] ->
        total_deleted

      ids ->
        schema = get_schema_from_query(query)
        {count, _} = from(q in schema, where: q.id in ^ids) |> Repo.delete_all()
        delete_in_batches_loop(query, batch_size, total_deleted + count)
    end
  end

  defp get_schema_from_query(%Ecto.Query{from: %{source: {_table, schema}}}), do: schema

  defp print_summary(counts) do
    total = Map.values(counts) |> Enum.sum()
    IO.puts("Offers:        #{counts.offers}")
    IO.puts("Bids:          #{counts.bids}")
    IO.puts("Campaigns:     #{counts.campaigns}")
    IO.puts("MediaRuns:     #{counts.media_runs}")
    IO.puts("TargetBands:   #{counts.target_bands}")
    IO.puts("Targets:       #{counts.targets}")
    IO.puts("TraitGroups:   #{counts.trait_groups}")
    IO.puts("MediaPieces:   #{counts.media_pieces}")
    IO.puts("MediaSequences: #{counts.media_sequences}")
    IO.puts("─" |> String.duplicate(40))
    IO.puts("TOTAL:         #{total}\n")
  end
end
