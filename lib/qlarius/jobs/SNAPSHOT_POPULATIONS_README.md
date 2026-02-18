# Target Population Snapshots

## Overview

**UPDATE: As of the latest version, snapshots are created INLINE during `PopulateTargetWorker` execution.**

The `matching_tags_snapshot` field captures **why** a specific `me_file` was assigned to a specific `target_band` by storing the matching tags in JSON format. This snapshot is now created automatically during population assignment, eliminating the race condition where offers could be created before snapshots were backfilled.

The `SnapshotBandPopulationsWorker` is now **DEPRECATED for new populations** and only used for backfilling legacy target_populations that have NULL snapshots.

## Data Structure

The `matching_tags_snapshot` field in `target_populations` stores a JSONB array of parent traits with their matching child tags:

```elixir
[
  [164, "Home Own/Rent", 1, [[166, "Rent", 2]]],
  [4, "Home Zip Code", 1, [[36566, "02140", 2140]]],
  [869, "Home Properties", 2, [
    [894, "Multi-story", 1],
    [878, "Central Heat/AC", 2],
    [882, "Fireplace - Gas", 2]
  ]],
  [885, "Home Type", 2, [[893, "Duplex", 3]]],
  [2839, "Home Fashion/Styles", 1011, [
    [2845, "Casual", 6],
    [2846, "Contemporary", 7],
    [2850, "English Country", 11]
  ]]
]
```

Each parent trait is: `[trait_id, trait_name, display_order, [child_tags]]`  
Each child tag is: `[tag_trait_id, tag_value, display_order]`

## Current Behavior (Inline Snapshots)

Snapshots are now created inline during `PopulateTargetWorker` execution.

When you click "Refresh Population" on a target, the system will:
1. Run `PopulateTargetWorker` to update me_file assignments
2. **Build snapshots inline** for all new target_populations (500 per batch)
3. Insert populations with snapshots already populated
4. Mark target as "populated" only after all snapshots are complete

This ensures that:
- No race condition exists between population and snapshot creation
- Offers are never created with NULL matching_tags_snapshot
- The "populated" status guarantees all snapshots are ready

## Manual Execution

### Snapshot a Single Band

```elixir
# In IEx console (iex -S mix):
Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: 123})
|> Oban.insert()
```

### Snapshot All Bands in a Target

```elixir
target_id = 60

Qlarius.Repo.all(
  from tb in Qlarius.Sponster.Campaigns.TargetBand,
  where: tb.target_id == ^target_id,
  select: tb.id
)
|> Enum.each(fn band_id ->
  Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: band_id})
  |> Oban.insert()
end)
```

### Backfill All Targets

```elixir
# Get all bands that have populations without snapshots
bands_needing_snapshots = 
  Qlarius.Repo.all(
    from tb in Qlarius.Sponster.Campaigns.TargetBand,
    join: tp in Qlarius.Sponster.Campaigns.TargetPopulation,
    on: tp.target_band_id == tb.id,
    where: is_nil(tp.matching_tags_snapshot),
    distinct: true,
    select: tb.id
  )

# Enqueue snapshot jobs for all of them
Enum.each(bands_needing_snapshots, fn band_id ->
  Qlarius.Jobs.SnapshotBandPopulationsWorker.new(%{band_id: band_id})
  |> Oban.insert()
end)
```

## Monitoring

Check Oban dashboard or logs to monitor progress:

```elixir
# Check pending snapshot jobs
Qlarius.Repo.all(
  from j in Oban.Job,
  where: j.worker == "Qlarius.Jobs.SnapshotBandPopulationsWorker" and j.state == "available"
)
```

## Performance

**Inline snapshot creation (current approach):**
- Processes 500 populations per batch within `PopulateTargetWorker`
- Snapshots built during the same transaction as population insertion
- For a target with 10,000 me_files across 3 bands:
  - ~20 batches total
  - All populations inserted with snapshots in one worker run
  - Estimated time: 2-3 minutes for 10K records (slightly slower but atomic)

**Legacy backfill approach (deprecated):**
- Each worker processes 500 me_files per batch
- Workers run in parallel (one per band)
- Estimated time: 1-2 minutes for 10K records

## Error Handling

- Snapshot failures do NOT affect population status
- Failed jobs retry up to 3 times
- If all retries fail, the job is marked as failed but populations remain valid
- Re-run manually if needed using the commands above

