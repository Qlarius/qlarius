# Target Population Snapshots

## Overview

The `SnapshotBandPopulationsWorker` creates a snapshot of matching tags for each `target_population` record. This snapshot captures **why** a specific `me_file` was assigned to a specific `target_band` by storing the matching tags in JSON format.

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

## Automatic Execution

Snapshot jobs run automatically after `PopulateTargetWorker` completes. One job is created per target band, allowing parallel processing.

When you click "Refresh Population" on a target, the system will:
1. Run `PopulateTargetWorker` to update me_file assignments
2. Automatically enqueue `SnapshotBandPopulationsWorker` jobs for each band
3. Each worker processes up to 500 me_files per batch

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

- Each worker processes 500 me_files per batch
- Workers run in parallel (one per band)
- For a target with 10,000 me_files across 3 bands:
  - ~20 batches per band
  - All 3 bands process simultaneously
  - Estimated time: 1-2 minutes for 10K records

## Error Handling

- Snapshot failures do NOT affect population status
- Failed jobs retry up to 3 times
- If all retries fail, the job is marked as failed but populations remain valid
- Re-run manually if needed using the commands above

