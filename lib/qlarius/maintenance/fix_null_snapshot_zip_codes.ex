defmodule Qlarius.Maintenance.FixNullSnapshotZipCodes do
  @moduledoc """
  One-time maintenance job to fix NULL or empty string zip code values in
  matching_tags_snapshot JSONB data across target_populations, offers, and ad_events.

  This job:
  1. Finds all snapshots with NULL/empty zip code tag values
  2. Looks up the correct zip code from me_file_tags
  3. Rebuilds the snapshot with the correct value
  4. Updates all three tables atomically

  ## Usage

  From IEx or Gigalixir console:

      # See diagnostic info first
      Qlarius.Maintenance.FixNullSnapshotZipCodes.diagnose()

      # Run the fix
      Qlarius.Maintenance.FixNullSnapshotZipCodes.run()

      # Run with custom batch size
      Qlarius.Maintenance.FixNullSnapshotZipCodes.run(batch_size: 50)
  """

  import Ecto.Query
  require Logger
  alias Qlarius.Repo
  alias Qlarius.Sponster.{AdEvent, Offer}
  alias Qlarius.Sponster.Campaigns.TargetPopulation
  alias Qlarius.YouData.MeFiles.MeFileTag

  @home_zip_code_trait_id 4
  @batch_size 100

  @doc """
  Diagnose the issue - show how many records need fixing in each table.

  Checks for TWO distinct issues:
  1. "null" inside snapshot JSON - e.g., [58587, null, 10028]
  2. Completely NULL snapshots - matching_tags_snapshot IS NULL
  """
  def diagnose do
    Logger.info("=== Diagnosing snapshot issues ===")

    # Issue 1: "null" values INSIDE existing snapshots
    tp_null_inside = count_null_zip_codes(TargetPopulation)
    offer_null_inside = count_null_zip_codes(Offer)
    ae_null_inside = count_null_zip_codes(AdEvent)

    Logger.info("\n1. Records with 'null' VALUES inside snapshots (fixable by this tool):")
    Logger.info("  target_populations: #{tp_null_inside}")
    Logger.info("  offers: #{offer_null_inside}")
    Logger.info("  ad_events: #{ae_null_inside}")
    Logger.info("  SUBTOTAL: #{tp_null_inside + offer_null_inside + ae_null_inside}")

    # Issue 2: Completely NULL snapshots
    tp_completely_null = count_completely_null_snapshots(TargetPopulation)
    offer_completely_null = count_completely_null_snapshots(Offer)
    ae_completely_null = count_completely_null_snapshots(AdEvent)

    Logger.info(
      "\n2. Records with COMPLETELY NULL snapshots (need BackfillMissingSnapshotsWorker):"
    )

    Logger.info("  target_populations: #{tp_completely_null}")
    Logger.info("  offers: #{offer_completely_null}")
    Logger.info("  ad_events: #{ae_completely_null}")
    Logger.info("  SUBTOTAL: #{tp_completely_null + offer_completely_null + ae_completely_null}")

    Logger.info(
      "\n=== TOTAL ISSUES: #{tp_null_inside + offer_null_inside + ae_null_inside + tp_completely_null + offer_completely_null + ae_completely_null} ==="
    )

    if tp_null_inside + offer_null_inside + ae_null_inside > 0 do
      Logger.info("\nSample records with 'null' inside snapshots:")

      sample_broken_records()
      |> Enum.take(5)
      |> Enum.each(fn record ->
        Logger.info("  me_file_id: #{record.me_file_id}, table: #{record.table}")
      end)
    end

    %{
      null_inside_snapshots: %{
        target_populations: tp_null_inside,
        offers: offer_null_inside,
        ad_events: ae_null_inside,
        subtotal: tp_null_inside + offer_null_inside + ae_null_inside
      },
      completely_null_snapshots: %{
        target_populations: tp_completely_null,
        offers: offer_completely_null,
        ad_events: ae_completely_null,
        subtotal: tp_completely_null + offer_completely_null + ae_completely_null
      },
      total:
        tp_null_inside + offer_null_inside + ae_null_inside + tp_completely_null +
          offer_completely_null + ae_completely_null
    }
  end

  @doc """
  Run the fix for all three tables.

  NOTE: This ONLY fixes "null" values INSIDE existing snapshots.
  For completely NULL snapshots, use BackfillMissingSnapshotsWorker or run it manually.

  ## Options
  - `:batch_size` - Number of records to process per batch (default: 100)
  - `:dry_run` - If true, only show what would be fixed without updating (default: false)
  """
  def run(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @batch_size)
    dry_run = Keyword.get(opts, :dry_run, false)

    Logger.info("=== Starting snapshot zip code fix ===")
    Logger.info("Batch size: #{batch_size}, Dry run: #{dry_run}")

    results = %{
      target_populations: fix_table(TargetPopulation, batch_size, dry_run),
      offers: fix_table(Offer, batch_size, dry_run),
      ad_events: fix_table(AdEvent, batch_size, dry_run)
    }

    Logger.info("=== Fix complete ===")
    Logger.info("Records updated:")
    Logger.info("  target_populations: #{results.target_populations}")
    Logger.info("  offers: #{results.offers}")
    Logger.info("  ad_events: #{results.ad_events}")
    Logger.info("  TOTAL: #{results.target_populations + results.offers + results.ad_events}")

    results
  end

  # Private functions

  defp count_null_zip_codes(table) do
    # Search for JSON null values (not quoted strings)
    # Look for patterns: ", null," or "[null," or ", null]"
    # Cast JSONB to text first, then search
    from(t in table,
      where: not is_nil(t.matching_tags_snapshot),
      where:
        fragment(
          "CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ?",
          t.matching_tags_snapshot,
          "%, null,%",
          t.matching_tags_snapshot,
          "%[null,%",
          t.matching_tags_snapshot,
          "%, null]%",
          t.matching_tags_snapshot,
          "%\"\",%"
        )
    )
    |> Repo.all()
    |> Enum.filter(&has_null_zip_code?/1)
    |> length()
  end

  defp count_completely_null_snapshots(table) do
    # Count records where the entire snapshot field is NULL
    from(t in table, where: is_nil(t.matching_tags_snapshot))
    |> Repo.aggregate(:count)
  end

  defp sample_broken_records do
    query = """
    SELECT me_file_id, 'target_populations' as table_name, matching_tags_snapshot
    FROM target_populations
    WHERE matching_tags_snapshot IS NOT NULL
      AND (CAST(matching_tags_snapshot AS text) LIKE '%, null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%[null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%, null]%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%"",%')
    UNION ALL
    SELECT me_file_id, 'offers' as table_name, matching_tags_snapshot
    FROM offers
    WHERE matching_tags_snapshot IS NOT NULL
      AND (CAST(matching_tags_snapshot AS text) LIKE '%, null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%[null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%, null]%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%"",%')
    UNION ALL
    SELECT me_file_id, 'ad_events' as table_name, matching_tags_snapshot
    FROM ad_events
    WHERE matching_tags_snapshot IS NOT NULL
      AND (CAST(matching_tags_snapshot AS text) LIKE '%, null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%[null,%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%, null]%'
           OR CAST(matching_tags_snapshot AS text) LIKE '%"",%')
    LIMIT 50
    """

    {:ok, result} = Repo.query(query)

    result.rows
    |> Enum.map(fn [me_file_id, table, snapshot] ->
      %{me_file_id: me_file_id, table: table, snapshot: snapshot}
    end)
    |> Enum.filter(&has_null_zip_code?/1)
  end

  defp fix_table(table, batch_size, dry_run) do
    table_name = table.__schema__(:source)
    Logger.info("Processing #{table_name}...")

    records = get_records_needing_fix(table)
    total = length(records)

    Logger.info("  Found #{total} records to fix")

    if dry_run do
      Logger.info("  [DRY RUN] Would update #{total} records")
      0
    else
      records
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)
      |> Enum.reduce(0, fn {batch, batch_num}, acc ->
        count = process_batch(table, batch, batch_num)
        Logger.info("  Batch #{batch_num}: Updated #{count} records")
        acc + count
      end)
    end
  end

  defp get_records_needing_fix(table) do
    # Get all records with JSON null values (not quoted strings)
    # Look for patterns: ", null," or "[null," or ", null]"
    # Cast JSONB to text first, then search
    from(t in table,
      where: not is_nil(t.matching_tags_snapshot),
      where:
        fragment(
          "CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ? OR CAST(? AS text) LIKE ?",
          t.matching_tags_snapshot,
          "%, null,%",
          t.matching_tags_snapshot,
          "%[null,%",
          t.matching_tags_snapshot,
          "%, null]%",
          t.matching_tags_snapshot,
          "%\"\",%"
        ),
      select: %{id: t.id, me_file_id: t.me_file_id, snapshot: t.matching_tags_snapshot}
    )
    |> Repo.all()
    |> Enum.filter(&has_null_zip_code?/1)
  end

  # Pattern match to check if this specific record has a null zip code value
  defp has_null_zip_code?(%{snapshot: %{"tags" => tags}}) do
    Enum.any?(tags, fn
      # Match Home Zip Code trait with null or empty child values
      [@home_zip_code_trait_id, _name, _order, child_tags] ->
        Enum.any?(child_tags, fn
          [_id, nil, _order] -> true
          [_id, "", _order] -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end

  defp has_null_zip_code?(_), do: false

  defp process_batch(table, records, batch_num) do
    me_file_ids = Enum.map(records, & &1.me_file_id) |> Enum.uniq()

    # Fetch correct zip codes for all me_files in this batch
    zip_codes = fetch_zip_codes_for_me_files(me_file_ids)

    # Update each record
    Enum.reduce(records, 0, fn record, count ->
      case Map.get(zip_codes, record.me_file_id) do
        nil ->
          Logger.warning(
            "  Batch #{batch_num}: No zip code found for me_file_id #{record.me_file_id}"
          )

          count

        zip_code ->
          case fix_snapshot(record.snapshot, zip_code) do
            {:ok, fixed_snapshot} ->
              update_record(table, record.id, fixed_snapshot)
              count + 1

            {:error, reason} ->
              Logger.error(
                "  Batch #{batch_num}: Failed to fix snapshot for #{table.__schema__(:source)} id=#{record.id}: #{inspect(reason)}"
              )

              count
          end
      end
    end)
  end

  defp fetch_zip_codes_for_me_files(me_file_ids) do
    # Get the correct zip code tag value from me_file_tags
    # We need to find the zip code trait (child of Home Zip Code parent trait)
    from(tag in MeFileTag,
      where: tag.me_file_id in ^me_file_ids,
      where: not is_nil(tag.parent_trait_id),
      where: tag.parent_trait_id == ^@home_zip_code_trait_id,
      where: not is_nil(tag.tag_value),
      where: tag.tag_value != "",
      select: {tag.me_file_id, tag.tag_value}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp fix_snapshot(%{"tags" => tags}, zip_code) when is_list(tags) do
    fixed_tags =
      Enum.map(tags, fn tag ->
        case tag do
          # Match the Home Zip Code parent trait
          [@home_zip_code_trait_id, parent_name, parent_order, child_tags] ->
            fixed_child_tags =
              Enum.map(child_tags, fn child_tag ->
                case child_tag do
                  # Fix NULL or empty string tag values
                  [child_id, tag_value, child_order] when is_nil(tag_value) or tag_value == "" ->
                    [child_id, zip_code, child_order]

                  # Keep valid tag values as-is
                  child_tag ->
                    child_tag
                end
              end)

            [@home_zip_code_trait_id, parent_name, parent_order, fixed_child_tags]

          # Keep other traits unchanged
          other_tag ->
            other_tag
        end
      end)

    {:ok, %{"tags" => fixed_tags}}
  end

  defp fix_snapshot(snapshot, _zip_code) do
    {:error, "Invalid snapshot structure: #{inspect(snapshot)}"}
  end

  defp update_record(table, id, new_snapshot) do
    from(t in table, where: t.id == ^id)
    |> Repo.update_all(
      set: [
        matching_tags_snapshot: new_snapshot,
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      ]
    )
  end
end
