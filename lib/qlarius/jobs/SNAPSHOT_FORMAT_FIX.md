# Snapshot Format Fix - matching_tags_snapshot Inconsistency

## Problem Identified

The `matching_tags_snapshot` field in `ad_events` and follow-up `offers` was being created in a **different format** than the snapshots in `target_populations`.

## Root Cause

**File:** `lib/qlarius/jobs/handle_offer_completion_worker.ex`  
**Function:** `get_current_me_file_tags/1` (lines 162-183, old version)

When the `HandleOfferCompletionWorker` created follow-up offers (after an ad_event completes), it was generating snapshots using a **flat structure** instead of the proper **nested array format**.

### Wrong Format (Before Fix)

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

**Issues with this format:**
- Flat list of traits (no parent-child nesting)
- String keys instead of atoms
- Includes unnecessary `snapshot_at` timestamp
- Missing `tag_value` and `display_order` fields
- Not filterable by trait_groups (no parent context)

### Correct Format (After Fix)

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

**Nested array structure:**
```
[
  parent_trait_id,
  "Parent Trait Name",
  parent_display_order,
  [
    [child_trait_id, "tag_value", child_display_order],
    [child_trait_id, "tag_value", child_display_order]
  ]
]
```

**Benefits of correct format:**
- Hierarchical structure (parent → children)
- Sorted by display_order for consistent presentation
- Filtered by band's trait_groups (only relevant traits included)
- Atom keys (Elixir convention)
- Includes tag_value (the actual data, e.g., "Male", "02140")
- Efficient nested array format for JSONB storage

## Why This Matters

### Data Flow

1. **Initial Offer Creation**
   - `CreateInitialPendingOffersWorker` creates offers
   - Copies snapshot from `target_population` ✅ **Correct format**

2. **Ad Event Creation**
   - `ThreeTap.create_click_ad_event` creates ad_events
   - Copies snapshot from `offer` ✅ **Correct format** (if offer was correct)

3. **Follow-up Offer Creation** ⚠️ **This was broken**
   - `HandleOfferCompletionWorker.create_next_offer` creates follow-up offers
   - Called `get_current_me_file_tags/1` which used **WRONG format** ❌
   - New offer → wrong snapshot
   - Ad events from that offer → inherit wrong snapshot ❌

4. **Backfill Worker**
   - `BackfillMissingSnapshotsWorker` replicates snapshots
   - Uses correct format from target_populations ✅

## Fix Applied

Replaced the `get_current_me_file_tags/1` function with three new functions that match the logic in `SnapshotBandPopulationsWorker`:

### 1. `get_current_me_file_tags_snapshot/2`
- **Parameters:** `me_file_id`, `target_band_id`
- **Purpose:** Fetches band's trait_groups and generates properly formatted snapshot
- **Returns:** `%{tags: [...]}` in nested array format

```elixir
defp get_current_me_file_tags_snapshot(me_file_id, target_band_id) do
  band =
    Repo.get!(TargetBand, target_band_id)
    |> Repo.preload(trait_groups: :traits)

  trait_metadata = build_trait_metadata(band.trait_groups)

  me_file_tags =
    from(mft in MeFileTag,
      join: t in Trait,
      on: mft.trait_id == t.id,
      where: mft.me_file_id == ^me_file_id,
      select: %{
        me_file_id: mft.me_file_id,
        trait_id: t.id,
        trait_name: t.trait_name,
        display_order: t.display_order,
        parent_trait_id: t.parent_trait_id,
        tag_value: mft.tag_value
      }
    )
    |> Repo.all()

  build_snapshot(me_file_tags, trait_metadata)
end
```

### 2. `build_trait_metadata/1`
- **Purpose:** Creates lookup structure from band's trait_groups
- **Returns:** Map of `%{parent_trait_id => %{name, display_order, child_ids}}`

```elixir
defp build_trait_metadata(trait_groups) do
  all_traits = Enum.flat_map(trait_groups, fn tg -> tg.traits end)

  parent_ids =
    all_traits
    |> Enum.map(& &1.parent_trait_id)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)

  parents =
    from(t in Trait,
      where: t.id in ^parent_ids,
      select: %{id: t.id, name: t.trait_name, display_order: t.display_order}
    )
    |> Repo.all()
    |> Map.new(&{&1.id, &1})

  all_traits
  |> Enum.group_by(& &1.parent_trait_id)
  |> Enum.map(fn {parent_id, child_traits} ->
    parent = Map.get(parents, parent_id)

    if parent do
      {parent_id,
       %{
         name: parent.name,
         display_order: parent.display_order,
         child_ids: Enum.map(child_traits, & &1.id) |> MapSet.new()
       }}
    end
  end)
  |> Enum.reject(&is_nil/1)
  |> Map.new()
end
```

### 3. `build_snapshot/2`
- **Purpose:** Filters tags by trait_groups and builds nested array structure
- **Returns:** `%{tags: [...]}` or `nil` if no matching tags

```elixir
defp build_snapshot(me_file_tags, trait_metadata) do
  snapshot =
    me_file_tags
    |> Enum.filter(fn tag ->
      Map.has_key?(trait_metadata, tag.parent_trait_id) &&
        MapSet.member?(trait_metadata[tag.parent_trait_id].child_ids, tag.trait_id)
    end)
    |> Enum.group_by(& &1.parent_trait_id)
    |> Enum.map(fn {parent_id, tags} ->
      meta = trait_metadata[parent_id]

      child_tags =
        tags
        |> Enum.map(fn tag ->
          [tag.trait_id, tag.tag_value, tag.display_order]
        end)
        |> Enum.sort_by(fn [_id, _val, order] -> order end)

      [parent_id, meta.name, meta.display_order, child_tags]
    end)
    |> Enum.sort_by(fn [_id, _name, order, _children] -> order end)

  case snapshot do
    [] -> nil
    data -> %{tags: data}
  end
end
```

## Files Modified

### `lib/qlarius/jobs/handle_offer_completion_worker.ex`

**Changes:**
1. Added aliases: `TargetBand`, `Trait`
2. Updated `create_next_offer/2` to call `get_current_me_file_tags_snapshot/2`
3. Replaced `get_current_me_file_tags/1` with three new functions
4. All functions use same logic as `SnapshotBandPopulationsWorker`

**Lines changed:** ~100 lines (162-256 in new version)

## Impact

### Before Fix
- ❌ Follow-up offers had wrong snapshot format
- ❌ Ad events from follow-up offers inherited wrong format
- ❌ Snapshots not filterable by trait_groups
- ❌ Missing tag_value data
- ❌ Inconsistent format across tables

### After Fix
- ✅ All offers use correct snapshot format
- ✅ All ad_events inherit correct format from offers
- ✅ Snapshots properly filtered by band's trait_groups
- ✅ Complete tag data (trait_id, tag_value, display_order)
- ✅ Consistent format across target_populations, offers, and ad_events

## Testing

### Manual Test
1. Find a campaign with active offers
2. Complete an ad_event to trigger HandleOfferCompletionWorker
3. Check the new offer's `matching_tags_snapshot` format
4. Verify it matches target_population snapshot format

```elixir
# In IEx console:
alias Qlarius.Repo
alias Qlarius.Sponster.{Offer, AdEvent}
alias Qlarius.Sponster.Campaigns.TargetPopulation

# Get a recent offer
offer = Repo.one(from o in Offer, order_by: [desc: o.id], limit: 1, preload: [:campaign])

# Get corresponding population
pop = Repo.get_by!(TargetPopulation, 
  me_file_id: offer.me_file_id, 
  target_band_id: offer.target_band_id
)

# Compare snapshots
pop.matching_tags_snapshot
offer.matching_tags_snapshot

# They should now have identical structure:
# %{tags: [[parent_id, "Parent Name", order, [[child_id, "value", order]]]]}
```

### Verify Ad Events
```elixir
# Check ad_events from this offer
ad_event = Repo.one(from ae in AdEvent, where: ae.offer_id == ^offer.id, limit: 1)

# Verify snapshot matches offer
ad_event.matching_tags_snapshot == offer.matching_tags_snapshot
```

## Prevention

To prevent this from happening again:

1. **Centralize snapshot logic** - Consider extracting to a shared module:
   ```elixir
   defmodule Qlarius.Sponster.SnapshotBuilder do
     def build_snapshot(me_file_id, target_band_id) do
       # Shared logic
     end
   end
   ```

2. **Add tests** - Test snapshot format consistency:
   ```elixir
   test "offer snapshots match population snapshots" do
     # Create population with snapshot
     # Create offer
     # Assert format matches
   end
   ```

3. **Schema validation** - Add Ecto changeset validation for snapshot structure

4. **Documentation** - Keep SNAPSHOT_POPULATIONS_README.md updated with format spec

## Related Files

- `lib/qlarius/jobs/snapshot_band_populations_worker.ex` - Source of truth for format
- `lib/qlarius/jobs/create_initial_pending_offers_worker.ex` - Initial offer creation (correct)
- `lib/qlarius/sponster/ads/three_tap.ex` - Ad event creation (correct)
- `lib/qlarius/jobs/backfill_missing_snapshots_worker.ex` - Backfill logic (correct)
- `lib/qlarius/jobs/SNAPSHOT_POPULATIONS_README.md` - Format documentation

