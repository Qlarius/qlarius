# Offers Unique Constraint

## Summary

Added a unique constraint to the `offers` table to prevent duplicate offers for the same campaign, me_file, and media_run combination.

## Changes Made

### 1. Migration: `20251109221023_add_unique_constraint_to_offers.exs`

- **Cleans up duplicates**: Removes any existing duplicate offers (keeps the oldest one)
- **Adds unique index**: Creates `offers_campaign_me_file_media_run_unique_index` on `[:campaign_id, :me_file_id, :media_run_id]`

### 2. Offer Schema: `lib/qlarius/sponster/offer.ex`

- Added `unique_constraint/2` to the changeset
- Constraint name: `:offers_campaign_me_file_media_run_unique_index`

### 3. Worker: `lib/qlarius/jobs/create_initial_pending_offers_worker.ex`

- Updated `Repo.insert_all/3` to explicitly specify:
  - `on_conflict: :nothing` - Silently skip duplicates
  - `conflict_target: [:campaign_id, :me_file_id, :media_run_id]` - Specify which columns to check

## Behavior

### Before
- Multiple offers could be created for the same campaign/me_file/media_run
- Re-running offer creation would create duplicates

### After
- Only one offer per campaign/me_file/media_run combination
- Re-running offer creation safely skips existing offers
- Worker logs actual insert count (excluding skipped duplicates)

## Database Command

To verify the constraint exists:

```sql
SELECT
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    tablename = 'offers'
    AND indexname = 'offers_campaign_me_file_media_run_unique_index';
```

## Testing

1. Launch a campaign → creates offers
2. Click "Refresh Offers" → deletes and recreates (no duplicates due to delete_all)
3. Manually create duplicate in IEx → constraint prevents it

```elixir
# This will succeed
Qlarius.Repo.insert(%Qlarius.Sponster.Offer{
  campaign_id: 1,
  me_file_id: 1,
  media_run_id: 1,
  # ... other fields
})

# This will fail with unique constraint error
Qlarius.Repo.insert(%Qlarius.Sponster.Offer{
  campaign_id: 1,
  me_file_id: 1,
  media_run_id: 1,
  # ... other fields
})
```

