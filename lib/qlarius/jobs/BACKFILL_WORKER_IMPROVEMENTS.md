# Backfill Worker Improvements

## Issue Discovered

The `BackfillMissingSnapshotsWorker` safety net was not effectively catching NULL snapshots because:

1. **Small Batch Size**: Only 100 populations per hour
2. **Inefficient Updates**: Individual queries instead of tracking counts
3. **Lack of Visibility**: No timing metrics or warning logs for missing snapshots

## Root Cause

With the previous async snapshot approach, there was a race condition:
- `PopulateTargetWorker` creates populations → marks target "populated"
- `CreateInitialPendingOffersWorker` sees "populated" → creates offers immediately
- `SnapshotBandPopulationsWorker` backfills snapshots asynchronously (too late)
- Backfill worker runs once per hour with small batch size (couldn't keep up)

## Improvements Made

### 1. Increased Batch Size
- **Before**: 100 populations per run
- **After**: 500 populations per run (5x faster)

### 2. Better Logging
- Added elapsed time tracking
- Added warning logs when snapshots can't be found for offers/events
- Added actual update counts (not just list lengths)

### 3. More Efficient Updates
- Changed from silent `Enum.each` to `Enum.reduce` that tracks counts
- Added explicit NULL checks in updates to prevent overwrites
- Returns actual number of records updated

### 4. Inline Snapshot Creation (Main Fix)
The backfill worker is now a **true safety net** because:
- `PopulateTargetWorker` creates snapshots inline (no race condition)
- `SyncMeFileToTargetPopulationsWorker` creates snapshots inline (no race condition)
- Backfill worker only catches edge cases and legacy data

## Testing the Backfill Worker

### Manual Execution
```elixir
# In IEx console (iex -S mix):
Qlarius.Jobs.BackfillMissingSnapshotsWorker.new(%{})
|> Oban.insert()
```

### Check for NULL Snapshots
```sql
-- Target populations
SELECT COUNT(*) FROM target_populations WHERE matching_tags_snapshot IS NULL;

-- Offers (should be 0 after inline fix)
SELECT COUNT(*) FROM offers WHERE matching_tags_snapshot IS NULL;

-- Ad events (should be 0 after inline fix)
SELECT COUNT(*) FROM ad_events WHERE matching_tags_snapshot IS NULL;
```

### Check Worker Execution
```elixir
# In IEx console:
alias Qlarius.Repo
import Ecto.Query

# Check recent backfill jobs
from(j in Oban.Job,
  where: j.worker == "Qlarius.Jobs.BackfillMissingSnapshotsWorker",
  where: j.attempted_at > ago(24, "hour"),
  order_by: [desc: j.attempted_at],
  select: %{
    id: j.id,
    state: j.state,
    attempted_at: j.attempted_at,
    completed_at: j.completed_at,
    errors: j.errors
  }
)
|> Repo.all()
```

## Current Schedule

Runs **every hour** at minute 0:
```elixir
{"0 * * * *", Qlarius.Jobs.BackfillMissingSnapshotsWorker}
```

With the inline snapshot fix, this should find **zero** NULL snapshots on most runs.

## Expected Behavior

**Before inline fix:**
- Backfill finds 100s-1000s of NULL snapshots per hour
- Can't keep up with new population creation
- Offers and ad_events created with NULL snapshots

**After inline fix:**
- Backfill finds 0-10 NULL snapshots per hour (only edge cases)
- Catches any rare failures or bugs
- All new records have snapshots from creation

## Monitoring

Watch for these log patterns:
- `"BackfillMissingSnapshotsWorker: No missing snapshots found"` ✅ Good (expected after fix)
- `"BackfillMissingSnapshotsWorker: Found X populations with missing snapshots"` ⚠️ Investigate if X > 10
- `"No snapshot found for offer/ad_event"` ⚠️ Indicates data integrity issue
