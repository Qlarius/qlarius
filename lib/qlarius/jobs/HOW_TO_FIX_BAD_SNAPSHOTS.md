# How to Fix Incorrectly Formatted Snapshots

This guide explains how to identify and correct snapshots that were created in the wrong format before the HandleOfferCompletionWorker fix was applied.

## Quick Start

### Option 1: Run Immediately (IEx Console)

```elixir
# Connect to your app console
# For Gigalixir: gigalixir ps:remote_console
# For local dev: iex -S mix

# Run the fix worker immediately
Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker.new(%{})
|> Oban.insert()
|> then(fn {:ok, job} -> 
  Oban.drain_queue(queue: :maintenance, with_limit: 1) 
end)
```

### Option 2: Enqueue for Background Processing

```elixir
# This will enqueue the job to run in the background
Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker.new(%{})
|> Oban.insert()

# Check the logs to monitor progress
```

## What Gets Fixed

The worker identifies and corrects snapshots with the **old incorrect format**:

### Incorrect Format (to be fixed)
```elixir
%{
  "tags" => [
    %{
      "trait_id" => 123,
      "trait_name" => "Male",
      "parent_trait_id" => 4
    },
    %{
      "trait_id" => 456,
      "trait_name" => "02140",
      "parent_trait_id" => 5
    }
  ],
  "snapshot_at" => "2025-12-20T16:45:30"
}
```

### Detection Method
The worker identifies incorrect snapshots by checking if they have:
- A `"snapshot_at"` key (string key)
- This is a reliable indicator of the old format

### Correct Format (what it becomes)
```elixir
%{
  tags: [
    [4, "Sex (Biological)", 1, [
      [123, "Male", 1]
    ]],
    [5, "Home Zip Code", 2, [
      [456, "02140", 2140]
    ]]
  ]
}
```

## How It Works

### Step 1: Scan Offers
```sql
-- Finds offers with incorrect format
SELECT id, me_file_id, target_band_id
FROM offers
WHERE matching_tags_snapshot IS NOT NULL
  AND matching_tags_snapshot ? 'snapshot_at'
```

### Step 2: Lookup Correct Snapshots
For each incorrect offer, lookup the corresponding `target_population` record and get its correctly formatted snapshot.

### Step 3: Update Offers
Replace the incorrect snapshot with the correct one from `target_population`.

### Step 4: Scan Ad Events
```sql
-- Finds ad_events with incorrect format
SELECT id, me_file_id, target_band_id
FROM ad_events
WHERE matching_tags_snapshot IS NOT NULL
  AND matching_tags_snapshot ? 'snapshot_at'
```

### Step 5: Update Ad Events
Replace the incorrect snapshot with the correct one from `target_population`.

## Checking for Bad Data

### Before Running the Fix

```elixir
# Count offers with incorrect format
Qlarius.Repo.one(
  from o in Qlarius.Sponster.Offer,
    where: not is_nil(o.matching_tags_snapshot),
    where: fragment("? \\? 'snapshot_at'", o.matching_tags_snapshot),
    select: count(o.id)
)

# Count ad_events with incorrect format
Qlarius.Repo.one(
  from ae in Qlarius.Sponster.AdEvent,
    where: not is_nil(ae.matching_tags_snapshot),
    where: fragment("? \\? 'snapshot_at'", ae.matching_tags_snapshot),
    select: count(ae.id)
)
```

### After Running the Fix

```elixir
# Should return 0 if all fixed
Qlarius.Repo.one(
  from o in Qlarius.Sponster.Offer,
    where: not is_nil(o.matching_tags_snapshot),
    where: fragment("? \\? 'snapshot_at'", o.matching_tags_snapshot),
    select: count(o.id)
)

# Should return 0 if all fixed
Qlarius.Repo.one(
  from ae in Qlarius.Sponster.AdEvent,
    where: not is_nil(ae.matching_tags_snapshot),
    where: fragment("? \\? 'snapshot_at'", ae.matching_tags_snapshot),
    select: count(ae.id)
)
```

## Sample Records to Verify

### Before Fix

```elixir
# Find a sample offer with incorrect format
alias Qlarius.Repo
alias Qlarius.Sponster.Offer

offer = Repo.one(
  from o in Offer,
    where: fragment("? \\? 'snapshot_at'", o.matching_tags_snapshot),
    limit: 1
)

# Inspect the bad format
IO.inspect(offer.matching_tags_snapshot, label: "BEFORE (incorrect)")

# Output will look like:
# BEFORE (incorrect): %{
#   "tags" => [%{"trait_id" => 123, ...}],
#   "snapshot_at" => "2025-12-20..."
# }
```

### After Fix

```elixir
# Reload the same offer
offer = Repo.get(Offer, offer.id)

# Inspect the corrected format
IO.inspect(offer.matching_tags_snapshot, label: "AFTER (correct)")

# Output will look like:
# AFTER (correct): %{
#   tags: [[4, "Sex (Biological)", 1, [[123, "Male", 1]]]]
# }
```

## Edge Cases Handled

### 1. No Corresponding Target Population
If an offer/ad_event has an incorrect snapshot but no matching `target_population` exists:
- The worker skips it (logs a warning)
- This shouldn't happen in practice since offers are always created from populations

### 2. Target Population Also Has NULL Snapshot
If the corresponding `target_population` has NULL `matching_tags_snapshot`:
- The worker skips it
- The BackfillMissingSnapshotsWorker will handle it in its next hourly run

### 3. Already Correct Format
If a snapshot already has the correct format:
- The JSONB query `? 'snapshot_at'` returns false
- Record is not included in the fix (no unnecessary updates)

## Performance Considerations

### Batch Processing
- Processes 100 records per batch
- Wrapped in transactions for atomicity
- Efficient JSONB queries using operators (`?` for key existence)

### Query Plan
The detection query uses JSONB operators:
```sql
EXPLAIN ANALYZE
SELECT id FROM offers 
WHERE matching_tags_snapshot ? 'snapshot_at';

-- Uses existing GIN index on matching_tags_snapshot
```

### Estimated Time
- **Small dataset (<1000 records):** ~10 seconds
- **Medium dataset (1000-10000 records):** ~1-2 minutes
- **Large dataset (>10000 records):** ~5-10 minutes

## Production Deployment

### Safe Deployment Steps

1. **Deploy code changes first**
   ```bash
   git push gigalixir main
   ```

2. **Check for bad data**
   ```bash
   gigalixir ps:remote_console
   
   # Run the count queries above
   ```

3. **Run the fix if needed**
   ```elixir
   Qlarius.Jobs.FixIncorrectSnapshotFormatsWorker.new(%{})
   |> Oban.insert()
   ```

4. **Monitor logs**
   ```bash
   gigalixir logs --num 100
   
   # Look for:
   # FixIncorrectSnapshotFormatsWorker: Found X offers with incorrect format
   # FixIncorrectSnapshotFormatsWorker: Fixed X offers and Y ad_events
   ```

5. **Verify fix completed**
   ```elixir
   # Counts should be 0
   Qlarius.Repo.one(
     from o in Qlarius.Sponster.Offer,
       where: fragment("? \\? 'snapshot_at'", o.matching_tags_snapshot),
       select: count(o.id)
   )
   ```

## Rollback (if needed)

If something goes wrong and you need to rollback:

```elixir
# The worker doesn't delete the old data, it overwrites it
# There's no automatic rollback, but you could:

# 1. Stop any running jobs
Oban.cancel_all_jobs()

# 2. The original incorrect data is gone once overwritten
# Your best bet is to restore from a database backup if needed
```

**Recommendation:** Take a database snapshot before running the fix in production.

## Monitoring

After deploying the fix, the BackfillMissingSnapshotsWorker (runs hourly) will prevent this issue from recurring:
- Catches any NULL snapshots
- Uses the correct format from target_populations
- Replicates to offers and ad_events

## Related Files

- `lib/qlarius/jobs/fix_incorrect_snapshot_formats_worker.ex` - The fix worker
- `lib/qlarius/jobs/handle_offer_completion_worker.ex` - Now uses correct format
- `lib/qlarius/jobs/SNAPSHOT_FORMAT_FIX.md` - Technical details of the issue
- `lib/qlarius/jobs/SNAPSHOT_POPULATIONS_README.md` - Format specification

## Support

If you encounter issues:
1. Check the Oban dashboard for failed jobs
2. Review logs for error messages
3. Verify database indexes exist (GIN index on matching_tags_snapshot)
4. Contact the development team with the job_id and error details

