# Campaign PubSub - Real-time Stats Updates

## Overview

This system provides real-time updates to the Campaigns Manager dashboard when campaign stats change, using Phoenix PubSub for efficient pub/sub messaging.

## Architecture

### PubSub Topics

Two subscription levels are supported:

1. **Campaign-specific**: `"campaign:#{campaign_id}"`
   - For single campaign detail views
   - Receives updates only for that specific campaign

2. **Marketer-wide**: `"marketer:#{marketer_id}:campaigns"`
   - For the campaigns dashboard/list
   - Receives updates for any campaign belonging to the marketer

### Event Types

| Event | Payload | Triggered By |
|-------|---------|-------------|
| `{:campaign_updated, campaign_id}` | Campaign ID | General campaign update |
| `{:target_populated, campaign_id}` | Campaign ID | Target population completes |
| `{:offers_created, campaign_id, count}` | Campaign ID + count | Offers successfully created |

## Components

### 1. CampaignPubSub Module
**Location:** `lib/qlarius/sponster/campaigns/campaign_pubsub.ex`

Central module for PubSub operations:

```elixir
# Subscribe to updates
CampaignPubSub.subscribe_to_marketer_campaigns(marketer_id)
CampaignPubSub.subscribe_to_campaign(campaign_id)

# Broadcast events
CampaignPubSub.broadcast_campaign_updated(campaign_id)
CampaignPubSub.broadcast_target_populated(campaign_id)
CampaignPubSub.broadcast_offers_created(campaign_id, count)
CampaignPubSub.broadcast_marketer_campaign_updated(marketer_id, campaign_id)
```

### 2. LiveView Integration
**Location:** `lib/qlarius_web/live/marketers/campaigns_manager_live.ex`

**Subscription:**
```elixir
def mount(_params, _session, socket) do
  if connected?(socket) && socket.assigns[:current_marketer] do
    CampaignPubSub.subscribe_to_marketer_campaigns(socket.assigns.current_marketer.id)
  end
  {:ok, socket}
end
```

**Event Handlers:**
```elixir
def handle_info({:campaign_updated, _campaign_id}, socket) do
  {:noreply, assign_campaigns_data(socket)}
end

def handle_info({:target_populated, _campaign_id}, socket) do
  {:noreply,
   socket
   |> put_flash(:info, "Target populated! Creating offers...")
   |> assign_campaigns_data()}
end

def handle_info({:offers_created, _campaign_id, count}, socket) do
  {:noreply,
   socket
   |> put_flash(:info, "#{count} offers created successfully")
   |> assign_campaigns_data()}
end
```

### 3. Worker Integration

#### CreateInitialPendingOffersWorker
**Location:** `lib/qlarius/jobs/create_initial_pending_offers_worker.ex`

Broadcasts after creating offers:
- Counts total offers inserted across all batches
- Broadcasts `{:offers_created, campaign_id, count}` if count > 0
- Also broadcasts general campaign update to marketer topic

#### PopulateTargetWorker
**Location:** `lib/qlarius/jobs/populate_target_worker.ex`

Broadcasts after target population completes:
- Finds all campaigns using the populated target
- Broadcasts `{:target_populated, campaign_id}` to each campaign
- Broadcasts general campaign update to each marketer

## User Experience

### Real-time Updates

**When launching a campaign:**
1. User clicks "Launch Campaign"
2. Flash: "Campaign launched! Populating target and building offers..."
3. Target populates (worker runs)
4. Flash: "Target populated! Creating offers..." *(auto-update via PubSub)*
5. Offers created (worker runs)
6. Flash: "50 offers created successfully" *(auto-update via PubSub)*
7. Stats update: Pending Offers shows 50 *(auto-update via PubSub)*

**When refreshing offers:**
1. User clicks "Refresh Offers"
2. Flash: "Refreshing offers for \"Campaign Name\"..."
3. Offers created (worker runs)
4. Flash: "50 offers created successfully" *(auto-update via PubSub)*
5. Stats update automatically *(auto-update via PubSub)*

**Multi-user scenario:**
- User A launches a campaign
- User B (same marketer) sees their dashboard update automatically
- User B sees flash notifications for target population and offer creation
- Both users see stats update in real-time

## Performance Considerations

### Current Implementation (Simple)
- Re-queries all campaign data on any update
- Efficient enough for typical usage (< 100 campaigns)
- Simple to maintain and debug

### Future Optimizations (if needed)

1. **Selective Refresh:**
```elixir
def handle_info({:campaign_updated, campaign_id}, socket) do
  updated_campaigns = 
    Enum.map(socket.assigns.campaigns, fn campaign ->
      if campaign.id == campaign_id do
        refresh_single_campaign(campaign_id)
      else
        campaign
      end
    end)
  {:noreply, assign(socket, :campaigns, updated_campaigns)}
end
```

2. **Broadcast Batching:**
- Implement GenServer to batch broadcasts
- Collect campaign updates for 2 seconds
- Broadcast once with all campaign IDs

3. **Incremental Updates:**
- Broadcast specific stat changes
- Update only changed stats in LiveView
- Requires calculating stats in workers

## Testing

### Manual Testing

1. **Single User:**
   - Launch a campaign
   - Watch for flash messages
   - Verify stats update automatically

2. **Multi-User:**
   - Open same marketer dashboard in two browsers
   - Launch campaign in browser A
   - Verify updates appear in browser B

### Automated Testing

```elixir
test "broadcasts campaign update when offers created" do
  campaign = campaign_fixture()
  
  Phoenix.PubSub.subscribe(Qlarius.PubSub, "campaign:#{campaign.id}")
  
  # Trigger offer creation
  CreateInitialPendingOffersWorker.perform(%{campaign_id: campaign.id})
  
  # Assert broadcast received
  assert_receive {:offers_created, ^campaign.id, count}, 5_000
  assert count > 0
end
```

## Troubleshooting

### Stats Not Updating

**Check:**
1. Is LiveView connected? (`connected?(socket)`)
2. Is `current_marketer` assigned in mount?
3. Are workers completing successfully? (check logs)
4. Are broadcasts being sent? (check worker logs)

**Debug:**
```elixir
# In LiveView
def handle_info(msg, socket) do
  IO.inspect(msg, label: "Received PubSub message")
  # ... handle normally
end
```

### Duplicate Updates

**Cause:** Multiple subscriptions to same topic

**Fix:** Only subscribe in `mount/3` when `connected?(socket)` is `true`

### Flash Messages Not Showing

**Cause:** Flash is cleared before user sees it

**Fix:** Ensure flash stays visible long enough (frontend timing)

## Future Enhancements

1. **Campaign Detail View:**
   - Subscribe to `campaign:#{id}` for single campaign
   - More granular updates (specific stats)
   - Live graph updates

2. **Notifications:**
   - Toast notifications for background updates
   - Sound/desktop notifications (opt-in)
   - Email notifications for major events

3. **Audit Trail:**
   - Store PubSub events in database
   - "What changed?" history view
   - Replay events for debugging

4. **Performance Metrics:**
   - Track broadcast latency
   - Monitor subscription counts
   - Alert on slow updates

