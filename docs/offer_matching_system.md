# Offer Matching System

## Overview

This document describes the comprehensive offer matching and management system that automatically matches MeFiles with campaign offers, handles offer activation with throttling, manages offer lifecycles, and maintains data integrity.

## Architecture

The system consists of 7 core Oban workers organized into 5 phases:

### Phase 1: Foundation (Activation & Throttling)
- **GlobalVariable** schema for configuration
- **ActivatePendingOffersWorker** - Handles time-based and throttled activation

### Phase 2: Completion & Renewal
- **HandleOfferCompletionWorker** - Creates next offers when media runs complete

### Phase 3: Tag-Driven Updates
- **SyncMeFileToTargetPopulationsWorker** - Updates target populations when tags change
- **ReconcileOffersForMeFileWorker** - Creates/removes offers based on population changes

### Phase 4: Dynamic Bid Updates
- **UpdateCampaignOffersWorker** - Updates offer amounts when bids change

### Phase 5: Cleanup & Monitoring
- **CleanupInvalidOffersWorker** - Removes orphaned and invalid offers

---

## Worker Details

### 1. ActivatePendingOffersWorker

**Queue:** `:activations`  
**Schedule:** Every 5 minutes  
**Purpose:** Activates pending offers based on `pending_until` date and throttling rules

**Logic:**
```
1. Get THROTTLE_AD_COUNT and THROTTLE_DAYS from global variables
2. Activate all unthrottled offers where pending_until <= now
3. For throttled offers:
   a. Group by me_file_id
   b. For each me_file:
      - Count current throttled offers (is_current=true, is_throttled=true)
      - Count completed throttled ads in last 7 days
      - remaining_slots = THROTTLE_AD_COUNT - max(current_count, completed_count)
      - Activate up to remaining_slots offers (oldest pending_until first)
```

**Throttling Rules:**
- Rule 1: Max THROTTLE_AD_COUNT throttled offers active at once
- Rule 2: Max THROTTLE_AD_COUNT throttled offers completed in rolling 7-day window
- Unthrottled offers activate immediately when pending_until passes

---

### 2. HandleOfferCompletionWorker

**Queue:** `:offers`  
**Trigger:** When `ad_event.is_offer_complete == true`  
**Purpose:** Creates next offer for a media run if not yet complete

**Logic:**
```
1. Check if media_run is complete:
   - Count completed ad_events for this me_file + media_run
   - If count >= media_run.frequency: EXIT
2. Check maximum_banner_count rule:
   - Count phase 1 ad_events for current offer
   - If count >= media_run.maximum_banner_count: EXIT
3. Create next offer:
   - Copy all attributes from completed offer
   - Set pending_until = completed_at + frequency_buffer_hours
   - Set is_current = false
   - Update matching_tags_snapshot to current me_file tags
```

**Media Run Completion:**
- A media run is complete when `completed_offer_count >= media_run.frequency`
- For 3-tap ads: completion means phase 2 reached OR maximum_banner_count exceeded

---

### 3. SyncMeFileToTargetPopulationsWorker

**Queue:** `:targets`  
**Trigger:** MeFileTag insert/delete (via context callbacks)  
**Unique:** Per me_file_id (2-minute debounce window)  
**Purpose:** Updates target_populations when a me_file's tags change

**Logic:**
```
1. Get all active campaigns (deactivated_at is null)
2. For each campaign:
   a. Find optimal target_band for this me_file
   b. Optimal = most specific band that matches all trait_groups
3. Compare with existing target_populations for this me_file
4. Insert new populations, delete invalid ones
5. Enqueue ReconcileOffersForMeFileWorker
```

**Callbacks:**
- `MeFiles.create_replace_mefile_tags/4` → enqueues sync worker
- `MeFiles.delete_mefile_tags/3` → enqueues sync worker with deleted_trait_ids

**Debouncing:**
- 2-minute unique window prevents duplicate jobs for rapid tag changes
- Replace strategy: latest job replaces pending job

---

### 4. ReconcileOffersForMeFileWorker

**Queue:** `:offers`  
**Trigger:** SyncMeFileToTargetPopulationsWorker completion  
**Unique:** Per me_file_id (1-minute window)  
**Purpose:** Creates/removes offers based on target_population changes

**Logic:**
```
1. Get target_bands this me_file is now in
2. Get eligible bids for these bands from active campaigns
3. Filter out bids where media_run is complete for this me_file
4. Compare with existing offers:
   a. Create offers for new (campaign, media_run, target_band) combinations
   b. Delete offers for combinations no longer valid
5. Broadcast offer updates
```

**Offer Creation:**
- `is_current = false`
- `pending_until = now` (activate on next worker run)
- `matching_tags_snapshot` = current me_file tags

---

### 5. UpdateCampaignOffersWorker

**Queue:** `:offers`  
**Trigger:** Bid amount updates from UI  
**Purpose:** Updates offer amounts when bids change

**Logic:**
```
1. For each bid change:
   - Update all offers where campaign_id + target_band_id + media_run_id match
   - Set new offer_amt and marketer_cost_amt
2. Broadcast campaign updates
```

**Note:** Updates both current and pending offers (accepts minor race condition risk)

---

### 6. CleanupInvalidOffersWorker

**Queue:** `:default`  
**Schedule:** Daily at 2:00 AM UTC  
**Purpose:** Removes orphaned and invalid offers

**Logic:**
```
1. Delete offers for deactivated campaigns
2. Delete orphaned offers (me_file no longer in target_population)
3. Delete offers for completed media runs:
   - Check each me_file + media_run combination
   - If completed_count >= frequency: delete remaining offers
```

---

## Global Configuration

### Global Variables

Stored in `global_variables` table, accessed via `Qlarius.System` context:

| Name | Default | Description |
|------|---------|-------------|
| `THROTTLE_AD_COUNT` | 3 | Max throttled offers active/completed per me_file |
| `THROTTLE_DAYS` | 7 | Rolling window for completed throttled ads |

**Usage:**
```elixir
Qlarius.System.get_global_variable_int("THROTTLE_AD_COUNT", 3)
Qlarius.System.set_global_variable("THROTTLE_AD_COUNT", "5")
```

---

## Oban Configuration

```elixir
config :qlarius, Oban,
  queues: [
    default: 10,
    targets: 5,
    offers: 10,
    activations: 3
  ],
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"*/5 * * * *", Qlarius.Jobs.ActivatePendingOffersWorker},
      {"0 0 * * *", Qlarius.Jobs.UpdateAgeTagsWorker},
      {"0 2 * * *", Qlarius.Jobs.CleanupInvalidOffersWorker}
    ]}
  ]
```

---

## Event Flow Diagrams

### Campaign Launch Flow
```
1. Campaign launched (launched_at set)
2. → CreateInitialPendingOffersWorker
3. → Creates offers for all target_populations
4. → Offers created with is_current=false, pending_until=launched_at
5. → ActivatePendingOffersWorker (next run)
6. → Activates offers based on throttling rules
```

### Tag Change Flow
```
1. User adds/removes tags
2. → MeFiles.create_replace_mefile_tags/4 or delete_mefile_tags/3
3. → SyncMeFileToTargetPopulationsWorker (debounced 2 min)
4. → Updates target_populations
5. → ReconcileOffersForMeFileWorker
6. → Creates new offers / Deletes invalid offers
7. → ActivatePendingOffersWorker (next run)
8. → Activates new offers
```

### Offer Completion Flow
```
1. User completes ad (phase 2 for 3-tap)
2. → AdEvent created with is_offer_complete=true
3. → Wallets.update_ledgers_from_ad_event
4. → HandleOfferCompletionWorker
5. → Checks if media_run complete
6. → If not complete: Creates next offer with buffer delay
7. → ActivatePendingOffersWorker (next run)
8. → Activates next offer (respecting throttling)
```

### Bid Update Flow
```
1. Marketer updates bid amounts
2. → Bids updated in database
3. → UpdateCampaignOffersWorker
4. → All matching offers updated
5. → PubSub broadcast to LiveViews
```

---

## PubSub Integration

### CampaignPubSub

**Topics:**
- `campaign:#{campaign_id}` - Single campaign updates
- `marketer:#{marketer_id}:campaigns` - All campaigns for a marketer

**Events:**
- `{:campaign_updated, campaign_id}`
- `{:offers_created, campaign_id, count}`
- `{:offers_activated}`

### MeFileStatsBroadcaster

**Topics:**
- `me_file_stats_updates:#{me_file_id}`

**Events:**
- `{:me_file_balance_updated, new_balance}`
- `{:me_file_offers_updated, me_file_id}`
- `{:me_file_stats_updated, me_file_id}`

---

## Testing Strategy

### Manual Testing Checklist

**Phase 1 - Activation:**
- [ ] Create offers with various `pending_until` dates
- [ ] Verify unthrottled offers activate immediately
- [ ] Verify throttled offers respect THROTTLE_AD_COUNT limit
- [ ] Complete 3 throttled offers, verify no more activate for 7 days

**Phase 2 - Completion:**
- [ ] Complete an offer, verify next offer created with buffer delay
- [ ] Complete offers until frequency reached, verify no more created
- [ ] Test maximum_banner_count rule for 3-tap ads

**Phase 3 - Tag Changes:**
- [ ] Add tags to me_file, verify new offers created
- [ ] Remove tags from me_file, verify offers deleted
- [ ] Rapidly change tags, verify debouncing works

**Phase 4 - Bid Updates:**
- [ ] Update bid amounts, verify offers updated
- [ ] Verify both current and pending offers updated

**Phase 5 - Cleanup:**
- [ ] Deactivate campaign, verify offers deleted
- [ ] Remove me_file from target, verify offers deleted
- [ ] Complete media run, verify offers deleted

---

## Performance Considerations

### Scalability

**Design for:**
- 100,000+ MeFiles
- 1,000+ active campaigns
- 10,000+ offers per campaign

**Optimizations:**
- Batch processing (1,000 records per batch)
- Streaming queries for large datasets
- Unique job constraints prevent duplicate work
- Debouncing for rapid changes (2-min for tags)

### Monitoring

**Key Metrics:**
- Offer activation rate (offers/minute)
- Average time from creation to activation
- Throttled vs unthrottled activation ratio
- Tag change → offer creation latency
- Cleanup job deleted offer counts

**Logs to Watch:**
- `"ActivatePendingOffersWorker: Activated N offers"`
- `"ReconcileOffersForMeFileWorker: Created N, deleted M offers"`
- `"HandleOfferCompletionWorker: Created next offer"`
- `"CleanupInvalidOffersWorker: Deleted N offers"`

---

## Troubleshooting

### Offers Not Activating

**Check:**
1. Is `pending_until` in the past?
2. Is campaign active (`deactivated_at` is null)?
3. For throttled offers: Has me_file hit throttle limits?
4. Check Oban dashboard for failed jobs

**Debug:**
```elixir
# Check pending offers
Repo.all(from o in Offer, where: o.is_current == false and o.pending_until < ^NaiveDateTime.utc_now(), limit: 10)

# Check throttle status for me_file
me_file_id = 123
Repo.one(from o in Offer, where: o.me_file_id == ^me_file_id and o.is_current == true and o.is_throttled == true, select: count())
```

### Offers Not Created After Tag Change

**Check:**
1. Did `SyncMeFileToTargetPopulationsWorker` run?
2. Is me_file in any target_populations?
3. Are campaigns active?
4. Is media_run already complete?

**Debug:**
```elixir
# Check target populations
Repo.all(from tp in TargetPopulation, where: tp.me_file_id == ^me_file_id)

# Manually trigger sync
SyncMeFileToTargetPopulationsWorker.new(%{me_file_id: 123}) |> Oban.insert()
```

### Next Offer Not Created After Completion

**Check:**
1. Did `HandleOfferCompletionWorker` run?
2. Is media_run frequency reached?
3. Is maximum_banner_count exceeded?

**Debug:**
```elixir
# Check completion count
Repo.one(from ae in AdEvent, where: ae.me_file_id == ^me_file_id and ae.media_run_id == ^media_run_id and ae.is_offer_complete == true, select: count())

# Check media_run frequency
Repo.one(from mr in MediaRun, where: mr.id == ^media_run_id, select: mr.frequency)
```

---

## Future Enhancements

### Phase 6 (Optional)
- Performance optimization based on production metrics
- Advanced throttling strategies (per campaign type, per category)
- Predictive offer creation (anticipate tag changes)
- A/B testing for activation timing
- Machine learning for optimal bid amounts

---

## Implementation Notes

### Design Decisions

1. **Debouncing**: 2-minute window for tag changes prevents excessive job creation
2. **Throttling**: Uses both active count and 7-day completion window to prevent overwhelming users
3. **Offer Creation Timing**: New offers created with `pending_until = now` for immediate eligibility
4. **Bid Updates**: Updates all offers (current + pending) accepting minor race condition risk
5. **Cleanup**: Runs at 2 AM when system load is lowest

### Code Organization

```
lib/qlarius/
├── system/
│   ├── global_variable.ex (schema)
│   └── system.ex (context)
├── jobs/
│   ├── activate_pending_offers_worker.ex
│   ├── handle_offer_completion_worker.ex
│   ├── sync_mefile_to_target_populations_worker.ex
│   ├── reconcile_offers_for_mefile_worker.ex
│   ├── update_campaign_offers_worker.ex
│   └── cleanup_invalid_offers_worker.ex
└── youdata/
    └── mefiles.ex (updated with callbacks)
```

### Callbacks

**Option C (Thorough Approach):**
- Ecto.Multi transactions ensure atomicity
- Jobs enqueued after successful transaction commit
- Provides safety net for direct Repo operations
- Documented inline for future maintainers

---

## Seed Data

Run to initialize global variables:
```bash
mix run priv/repo/seeds/global_variables_seed.exs
```

---

## Related Documentation

- [Campaign Management](campaigns.md)
- [Bid Management](bid_management.md)
- [Target Populations](targets.md)
- [MeFile Builder](mefile_builder.md)

