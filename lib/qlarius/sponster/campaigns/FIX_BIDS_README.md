# Fix Campaign Bids

This document explains how campaign bids are automatically managed.

## Automatic Bid Management

When campaigns are loaded in the Campaigns Manager, the system automatically:
1. Creates any missing bids for target bands
2. Validates the entire bid set against requirements:
   - Minimum bid of $0.10
   - Bids must increase by at least $0.01 from outer to inner bands
3. Adjusts existing bids only when necessary to meet requirements

This ensures campaigns always have valid bid sets without user intervention.

## The Problem (Historical)

Legacy campaigns may have had:
- Target bands without corresponding bids
- Invalid bid amounts (< $0.10)
- Bids that violated ordering rules

## The Solution

Bids are now automatically managed. The system will keep existing bid values whenever possible and only adjust them when needed to validate the entire bid set.

## How to Fix

### Option 1: Fix All Campaigns (Recommended)

Run this in IEx (local or production):

```elixir
Qlarius.Sponster.Campaigns.ensure_all_campaigns_have_bids()
```

This will:
- Check every campaign
- For campaigns with missing bids, delete ALL existing bids and recreate them using the standard pricing algorithm
- Display a summary of actions taken

### Option 2: Fix a Single Campaign

If you only want to fix one campaign:

```elixir
Qlarius.Sponster.Campaigns.ensure_all_bands_have_bids(campaign_id)
```

## Production (Gigalixir)

To run on production:

```bash
# SSH into the app
gigalixir ps:remote_console

# Run the fix
Qlarius.Sponster.Campaigns.ensure_all_campaigns_have_bids()
```

## Notes

- The fix uses the same algorithm as campaign creation:
  - Bands are sorted by ID (smallest = bullseye, largest = outermost)
  - Outermost band gets $0.10
  - Each inner band adds $0.01
  - Cost = (offer_amt × 1.5) + $0.10
- If ANY bands are missing bids, ALL bids are recreated to maintain consistent pricing
- This is a safe operation - it only affects campaigns with missing bids
- The transaction will rollback if there are any errors

