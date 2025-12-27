defmodule Qlarius.Maintenance.SplitLedgerEntryDescriptions do
  @moduledoc """
  Maintenance utility to categorize ledger entry descriptions and populate meta_1.

  ## Rules

  1. **"Banner -"** → meta_1 = "Banner Tap", remove "Banner - " prefix from description
  2. **"Text/Jump -"** → meta_1 = "Text/Jump", remove "Text/Jump - " prefix from description
  3. **"Tiqit purchase"** → meta_1 = "Tiqit Purchase", keep description unchanged
  4. **All others** → meta_1 stays NULL, description unchanged

  Only processes entries where meta_1 is currently NULL or empty.

  ## Usage

  In IEx:

      iex> alias Qlarius.Maintenance.SplitLedgerEntryDescriptions
      iex> SplitLedgerEntryDescriptions.diagnose()
      iex> SplitLedgerEntryDescriptions.run()

  Via Mix:

      mix run -e "Qlarius.Maintenance.SplitLedgerEntryDescriptions.run()"

  ## Examples

  | Current Description | New meta_1 | New Description |
  |---------------------|------------|-----------------|
  | "Banner - Ad viewed" | "Banner Tap" | "Ad viewed" |
  | "Text/Jump - Clicked link" | "Text/Jump" | "Clicked link" |
  | "Tiqit purchase - Bought ticket" | "Tiqit Purchase" | "Tiqit purchase - Bought ticket" |
  | "Other description" | NULL | "Other description" |
  """

  require Logger
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Wallets.LedgerEntry

  @batch_size 100

  # Pattern matching rules: {prefix_to_match, meta_1_value, remove_prefix?}
  @patterns [
    {"Banner - ", "Banner Tap", true},
    {"Text/Jump - ", "Text/Jump", true},
    {"Tiqit purchase", "Tiqit Purchase", false}
  ]

  @doc """
  Diagnoses how many entries would be affected by each pattern.
  Shows sample entries that would be modified.
  """
  def diagnose(sample_size \\ 10) do
    Logger.info("=== Diagnosing ledger entry descriptions ===")

    total_count = Repo.aggregate(LedgerEntry, :count)
    Logger.info("Total ledger entries: #{total_count}")

    # Count entries that will be processed per pattern
    pattern_counts =
      Enum.map(@patterns, fn {prefix, meta_1_value, _remove_prefix?} ->
        count =
          from(le in LedgerEntry,
            where: fragment("? LIKE ?", le.description, ^"#{prefix}%"),
            where: is_nil(le.meta_1) or le.meta_1 == ""
          )
          |> Repo.aggregate(:count)

        {prefix, meta_1_value, count}
      end)

    Logger.info("\n=== Entries to process by pattern ===")

    Enum.each(pattern_counts, fn {prefix, meta_1_value, count} ->
      Logger.info("  \"#{prefix}\" → meta_1: \"#{meta_1_value}\" (#{count} entries)")
    end)

    total_to_process = Enum.reduce(pattern_counts, 0, fn {_, _, count}, acc -> acc + count end)
    Logger.info("\nTotal entries to process: #{total_to_process}")

    # Show samples for each pattern
    if total_to_process > 0 do
      Logger.info("\n=== Sample entries per pattern (showing up to #{sample_size} each) ===\n")

      Enum.each(@patterns, fn {prefix, meta_1_value, _remove_prefix?} ->
        entries =
          from(le in LedgerEntry,
            where: fragment("? LIKE ?", le.description, ^"#{prefix}%"),
            where: is_nil(le.meta_1) or le.meta_1 == "",
            limit: ^sample_size
          )
          |> Repo.all()

        if length(entries) > 0 do
          IO.puts("--- Pattern: \"#{prefix}\" → \"#{meta_1_value}\" ---\n")

          Enum.each(entries, fn entry ->
            {new_meta_1, new_description} = process_description(entry.description)
            display_entry_preview(entry, new_meta_1, new_description)
          end)

          IO.puts("")
        end
      end)
    end

    summary = %{
      total_entries: total_count,
      entries_to_modify: total_to_process,
      entries_to_skip: total_count - total_to_process,
      by_pattern: pattern_counts
    }

    Logger.info("\n=== Summary ===")
    Logger.info("Total entries: #{summary.total_entries}")
    Logger.info("Will modify: #{summary.entries_to_modify}")
    Logger.info("Will skip: #{summary.entries_to_skip}")

    {:ok, summary}
  end

  @doc """
  Runs the categorization operation on all applicable ledger entries.

  ## Options

  - `:dry_run` - When `true`, only previews changes without updating (default: `false`)
  - `:batch_size` - Number of records to process per batch (default: `100`)

  ## Examples

      # Dry run first
      SplitLedgerEntryDescriptions.run(dry_run: true)

      # Run actual update
      SplitLedgerEntryDescriptions.run()

      # Custom batch size
      SplitLedgerEntryDescriptions.run(batch_size: 50)
  """
  def run(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    batch_size = Keyword.get(opts, :batch_size, @batch_size)

    mode = if dry_run, do: "DRY RUN", else: "LIVE"
    Logger.info("=== Starting ledger entry description processing (#{mode}) ===")

    # Build query for all entries matching any pattern
    entries =
      from(le in LedgerEntry,
        where: is_nil(le.meta_1) or le.meta_1 == ""
      )
      |> where_matches_any_pattern()
      |> Repo.all()

    total_count = length(entries)
    Logger.info("Found #{total_count} entries to process")

    if total_count == 0 do
      Logger.info("No entries to process")
      {:ok, %{processed: 0, updated: 0, skipped: 0, errors: 0}}
    else
      process_entries(entries, batch_size, dry_run)
    end
  end

  @doc """
  Verifies that the operation worked correctly.
  Shows counts of entries by meta_1 value.
  """
  def verify do
    Logger.info("=== Verifying categorization ===")

    # Count by meta_1 value
    results =
      from(le in LedgerEntry,
        where: not is_nil(le.meta_1) and le.meta_1 != "",
        group_by: le.meta_1,
        select: {le.meta_1, count(le.id)}
      )
      |> Repo.all()

    Logger.info("\n=== Entries by meta_1 value ===")

    Enum.each(results, fn {meta_1, count} ->
      Logger.info("  \"#{meta_1}\": #{count} entries")
    end)

    total_categorized = Enum.reduce(results, 0, fn {_, count}, acc -> acc + count end)
    Logger.info("\nTotal categorized entries: #{total_categorized}")

    # Check for entries that still match patterns but don't have meta_1
    still_pending =
      from(le in LedgerEntry,
        where: is_nil(le.meta_1) or le.meta_1 == ""
      )
      |> where_matches_any_pattern()
      |> Repo.aggregate(:count)

    Logger.info("Entries still needing processing: #{still_pending}")

    if still_pending > 0 do
      Logger.warning("There are still entries that need processing!")
    else
      Logger.info("✓ All applicable entries have been processed")
    end

    # Show sample entries for each meta_1 value
    Logger.info("\n=== Sample entries per category ===")

    Enum.each(results, fn {meta_1, _count} ->
      sample =
        from(le in LedgerEntry,
          where: le.meta_1 == ^meta_1,
          limit: 3
        )
        |> Repo.all()

      IO.puts("\n--- meta_1: \"#{meta_1}\" ---")

      Enum.each(sample, fn entry ->
        IO.puts("  ID #{entry.id}: #{inspect(entry.description)}")
      end)
    end)

    summary = %{
      categorized_entries: total_categorized,
      by_category: results,
      still_pending: still_pending
    }

    {:ok, summary}
  end

  # Private Functions

  defp where_matches_any_pattern(query) do
    Enum.reduce(@patterns, query, fn {prefix, _, _}, acc_query ->
      or_where(acc_query, [le], fragment("? LIKE ?", le.description, ^"#{prefix}%"))
    end)
  end

  defp process_entries(entries, batch_size, dry_run) do
    entries
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{processed: 0, updated: 0, skipped: 0, errors: 0},
      fn {batch, batch_num}, acc ->
        Logger.info("Processing batch #{batch_num} (#{length(batch)} entries)...")
        batch_result = process_batch(batch, dry_run)

        %{
          processed: acc.processed + batch_result.processed,
          updated: acc.updated + batch_result.updated,
          skipped: acc.skipped + batch_result.skipped,
          errors: acc.errors + batch_result.errors
        }
      end
    )
    |> tap(fn results ->
      Logger.info("\n=== Processing complete ===")
      Logger.info("Total processed: #{results.processed}")
      Logger.info("Updated: #{results.updated}")
      Logger.info("Skipped: #{results.skipped}")
      Logger.info("Errors: #{results.errors}")
    end)
    |> then(&{:ok, &1})
  end

  defp process_batch(batch, dry_run) do
    Enum.reduce(batch, %{processed: 0, updated: 0, skipped: 0, errors: 0}, fn entry, acc ->
      result = process_entry(entry, dry_run)

      case result do
        {:ok, :updated} ->
          %{acc | processed: acc.processed + 1, updated: acc.updated + 1}

        {:ok, :skipped} ->
          %{acc | processed: acc.processed + 1, skipped: acc.skipped + 1}

        {:error, _reason} ->
          %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
      end
    end)
  end

  defp process_entry(entry, dry_run) do
    {new_meta_1, new_description} = process_description(entry.description)

    cond do
      is_nil(new_meta_1) ->
        Logger.debug("Skipping entry #{entry.id}: no matching pattern")
        {:ok, :skipped}

      dry_run ->
        Logger.debug("DRY RUN - Would update entry #{entry.id}")
        display_entry_preview(entry, new_meta_1, new_description)
        {:ok, :updated}

      true ->
        update_entry(entry, new_meta_1, new_description)
    end
  end

  defp process_description(description) when is_binary(description) do
    # Try each pattern in order
    Enum.find_value(@patterns, {nil, description}, fn {prefix, meta_1_value, remove_prefix?} ->
      if String.starts_with?(description, prefix) do
        new_description =
          if remove_prefix? do
            description
            |> String.replace_prefix(prefix, "")
            |> String.trim()
          else
            description
          end

        {meta_1_value, new_description}
      end
    end)
  end

  defp process_description(_), do: {nil, nil}

  defp update_entry(entry, new_meta_1, new_description) do
    changeset =
      entry
      |> LedgerEntry.changeset(%{
        meta_1: new_meta_1,
        description: new_description
      })

    case Repo.update(changeset) do
      {:ok, _updated_entry} ->
        Logger.debug("Updated entry #{entry.id}")
        {:ok, :updated}

      {:error, changeset} ->
        Logger.error("Failed to update entry #{entry.id}: #{inspect(changeset.errors)}")
        {:error, changeset.errors}
    end
  end

  defp display_entry_preview(entry, new_meta_1, new_description) do
    IO.puts("\n--- Entry ID: #{entry.id} ---")
    IO.puts("Current:")
    IO.puts("  description: #{inspect(entry.description)}")
    IO.puts("  meta_1: #{inspect(entry.meta_1)}")
    IO.puts("After update:")
    IO.puts("  meta_1: #{inspect(new_meta_1)}")
    IO.puts("  description: #{inspect(new_description)}")
  end
end
