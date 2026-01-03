# Qlarius Maintenance Utilities

This directory contains one-time maintenance scripts and diagnostic utilities for the Qlarius application. These are separate from regular Oban jobs and are meant to be run manually via IEx or the Gigalixir console.

## Available Utilities

### 1. SwapMobileNumbers

**Module**: `Qlarius.Maintenance.SwapMobileNumbers`

Utility to safely swap mobile numbers between two user accounts. This is useful when you need to transfer a validated mobile number from one user to another for authentication purposes.

#### What Gets Swapped

- `mobile_number_encrypted` (encrypted phone number)
- `mobile_number_hash` (hash used for unique constraint)
- `phone_verified_at` (verification timestamp)

#### Safety Features

- Uses database transaction for atomicity (all-or-nothing)
- Validates both users exist before attempting swap
- No data is deleted until successful save
- Detailed logging and error reporting

#### Usage

```elixir
# Step 1: Diagnose first - see what would be swapped
Qlarius.Maintenance.SwapMobileNumbers.diagnose("alice", "bob")

# Output:
# === Mobile Number Swap Diagnosis ===
# User 1 alias: alice
# User 2 alias: bob
# 
# --- User 1: alice (ID: 123) ---
# Mobile Number: +15551234567
# Encrypted: <24 bytes>
# Hash: <32 bytes>
# Verified: Yes (2024-12-26 15:30:00 UTC)
# 
# --- User 2: bob (ID: 456) ---
# Mobile Number: +15559876543
# Encrypted: <24 bytes>
# Hash: <32 bytes>
# Verified: No
# 
# --- After Swap Preview ---
# User 1 (alice) would get: +15559876543
# User 2 (bob) would get: +15551234567

# Step 2: Perform the actual swap
{:ok, result} = Qlarius.Maintenance.SwapMobileNumbers.swap("alice", "bob")

# Step 3: Verify the swap was successful
Qlarius.Maintenance.SwapMobileNumbers.verify_swap(
  "alice", 
  "bob",
  "+15559876543",  # Expected for alice after swap
  "+15551234567"   # Expected for bob after swap
)
```

#### Common Use Cases

1. **User merged accounts**: User has two accounts and wants to consolidate
2. **Number ported**: User switched accounts but wants to keep the same verified number
3. **Data correction**: Mobile number was assigned to wrong user by mistake

#### Error Handling

The swap will fail with clear error messages if:
- Either user doesn't exist
- Both aliases refer to the same user
- Database constraint violations occur
- Transaction fails for any reason

### 2. SnapshotQueries

**Module**: `Qlarius.Maintenance.SnapshotQueries`

Diagnostic and query utilities for analyzing `matching_tags_snapshot` data across `target_populations`, `offers`, and `ad_events` tables.

#### Common Usage

```elixir
# Quick diagnostics - count issues by type
Qlarius.Maintenance.SnapshotQueries.count_by_issue_type()

# Find all mismatches between tables
mismatches = Qlarius.Maintenance.SnapshotQueries.find_snapshot_mismatches()

# Find records with NULL zip codes in snapshots
Qlarius.Maintenance.SnapshotQueries.with_null_tag_value(
  Qlarius.Sponster.TargetPopulation, 
  4  # Home Zip Code trait_id
)

# Find all offers for a specific zip code
Qlarius.Maintenance.SnapshotQueries.with_tag_value(
  Qlarius.Sponster.Offer,
  4,        # Home Zip Code trait_id
  "02140"   # zip code value
)

# Sample snapshots from each table to inspect structure
Qlarius.Maintenance.SnapshotQueries.sample_snapshots(5)

# Get detailed list of all records needing fixes
Qlarius.Maintenance.SnapshotQueries.records_needing_snapshot_fix()
```

### 3. FixNullSnapshotZipCodes

**Module**: `Qlarius.Maintenance.FixNullSnapshotZipCodes`

One-time job to fix NULL or empty string zip code values **INSIDE** `matching_tags_snapshot` JSONB data.

#### Important Distinction

There are **TWO types** of NULL issues:

1. **"null" inside snapshot JSON** (this tool fixes this)
   - Snapshot exists but has `null` values: `[58587, null, 10028]`
   - Fixable by looking up correct value in `me_file_tags`

2. **Completely NULL snapshots** (BackfillMissingSnapshotsWorker fixes this)
   - The entire `matching_tags_snapshot` field is NULL
   - Needs to be generated from scratch, not fixed

#### How It Works

1. Finds all snapshots with `null`/`""` zip code tag values **inside the JSON**
2. Looks up the correct zip code from `me_file_tags`
3. Rebuilds the snapshot with the correct value
4. Updates all three tables atomically in batches

#### Usage

```elixir
# Step 1: Diagnose the issue first
Qlarius.Maintenance.FixNullSnapshotZipCodes.diagnose()
# Output:
# === Diagnosing snapshot issues ===
# 
# 1. Records with 'null' VALUES inside snapshots (fixable by this tool):
#   target_populations: 0
#   offers: 0
#   ad_events: 0
#   SUBTOTAL: 0
# 
# 2. Records with COMPLETELY NULL snapshots (need BackfillMissingSnapshotsWorker):
#   target_populations: 17955
#   offers: 159565
#   ad_events: 33838
#   SUBTOTAL: 211358
# 
# === TOTAL ISSUES: 211358 ===

# Step 2: Do a dry run to see what would be fixed (doesn't update anything)
Qlarius.Maintenance.FixNullSnapshotZipCodes.run(dry_run: true)

# Step 3: Run the actual fix
Qlarius.Maintenance.FixNullSnapshotZipCodes.run()

# Optional: Run with custom batch size
Qlarius.Maintenance.FixNullSnapshotZipCodes.run(batch_size: 50)
```

#### When to Use

Run this if you notice:
- Literal `null` values **inside** snapshot JSON (e.g., `[58587, null, 10028]`)
- Empty strings for zip codes **inside** snapshots
- After data migration or bulk updates that may have corrupted snapshot values

**Do NOT use this for:**
- Completely NULL snapshots (entire field is NULL) - use `BackfillMissingSnapshotsWorker` instead
- Missing snapshots that need to be generated from scratch

## Snapshot Data Structure

The `matching_tags_snapshot` field uses this JSONB structure:

```json
{
  "tags": [
    [4, "Home Zip Code", 1, [[58587, "02140", 10028]]],
    [1, "Sex (Biological)", 1, [[2, "Female", 1]]],
    [284, "Children Sex(BioGender):Age", 2, [[1290, "Boy: 18-23 mos*", 6]]]
  ]
}
```

Each parent trait is: `[parent_trait_id, parent_name, display_order, [child_tags]]`

Each child tag is: `[child_trait_id, tag_value, display_order]`

### NULL Value Issues

Sometimes the `tag_value` (second element in child tag array) can be:
- `null` - explicitly NULL in JSON
- `""` - empty string

Both are invalid and need to be fixed by looking up the correct value from `me_file_tags`.

### 4. FixMissingMobileNumbers

**Module**: `Qlarius.Maintenance.FixMissingMobileNumbers`

Utility to fix users who registered but had their mobile numbers not saved due to a bug in the registration flow.

#### The Bug

Prior to the fix, `Accounts.register_new_user/1` was calling `User.changeset/2` instead of `User.registration_changeset/2`. The regular changeset doesn't handle mobile number encryption, so even though users entered their phone numbers during registration, they were never encrypted and saved to the database. This prevented users from logging back in.

#### What It Does

- Encrypts and saves the mobile number for affected users
- Sets both `mobile_number_encrypted` and `mobile_number_hash` fields
- Uses the same encryption logic as a proper registration

#### Usage

```elixir
# Step 1: Find all users without mobile numbers
Qlarius.Maintenance.FixMissingMobileNumbers.find_users_without_mobile()

# Output:
# === Users without mobile numbers ===
# Found 1 users
# ID: 200393, Alias: happy-slough-8114, Registered: 2026-01-03 09:44:44, Last login: 2026-01-03 09:44:44

# Step 2: Dry run to preview the fix (doesn't update anything)
Qlarius.Maintenance.FixMissingMobileNumbers.fix_user_dry_run(200393, "+15551234567")

# Step 3: Actually fix the user
Qlarius.Maintenance.FixMissingMobileNumbers.fix_user(200393, "+15551234567")

# Output:
# === Fixing user 200393 (happy-slough-8114) ===
# Current mobile_number_encrypted: nil
# Current mobile_number_hash: nil
# New mobile number: +15551234567
# 
# ✅ SUCCESS!
# Updated mobile_number_encrypted: "+15551234567"
# Updated mobile_number_hash: "A1B2C3..."
```

#### When to Use

Run this when:
- Users report they can't log in with their phone number
- New registrations show users with `nil` mobile numbers
- You need to manually add/update a user's mobile number

#### Safety

- Uses the same `User.registration_changeset/2` as registration
- Validates and normalizes phone numbers (converts to E.164 format)
- Checks for unique constraint violations
- Can be tested with dry run mode

### 5. SplitLedgerEntryDescriptions

**Module**: `Qlarius.Maintenance.SplitLedgerEntryDescriptions`

Utility to categorize ledger entry descriptions by pattern and populate the `meta_1` column.

#### What It Does

Applies specific rules based on description prefixes (case-sensitive):

1. **"Banner - "** → meta_1 = "Banner Tap", removes "Banner - " from description
2. **"Text/Jump - "** → meta_1 = "Text/Jump", removes "Text/Jump - " from description
3. **"Tiqit purchase"** → meta_1 = "Tiqit Purchase", keeps description unchanged
4. **All others** → meta_1 stays NULL, description unchanged

Only processes entries where `meta_1` is NULL or empty.

#### Usage

```elixir
# Step 1: Diagnose - see what would change
Qlarius.Maintenance.SplitLedgerEntryDescriptions.diagnose()

# Output shows:
# === Entries to process by pattern ===
#   "Banner - " → meta_1: "Banner Tap" (25 entries)
#   "Text/Jump - " → meta_1: "Text/Jump" (18 entries)
#   "Tiqit purchase" → meta_1: "Tiqit Purchase" (10 entries)
# 
# Total entries to process: 53
# 
# === Sample entries per pattern ===
# --- Pattern: "Banner - " → "Banner Tap" ---
# 
# --- Entry ID: 123 ---
# Current:
#   description: "Banner - Ad viewed for Product X"
#   meta_1: nil
# After update:
#   meta_1: "Banner Tap"
#   description: "Ad viewed for Product X"

# Step 2: Dry run - preview without updating
Qlarius.Maintenance.SplitLedgerEntryDescriptions.run(dry_run: true)

# Step 3: Run actual update
Qlarius.Maintenance.SplitLedgerEntryDescriptions.run()

# Step 4: Verify it worked
Qlarius.Maintenance.SplitLedgerEntryDescriptions.verify()

# Optional: Custom batch size
Qlarius.Maintenance.SplitLedgerEntryDescriptions.run(batch_size: 50)
```

#### Examples

| Current Description | New meta_1 | New Description |
|---------------------|------------|-----------------|
| `"Banner - Ad viewed"` | `"Banner Tap"` | `"Ad viewed"` |
| `"Text/Jump - Clicked link"` | `"Text/Jump"` | `"Clicked link"` |
| `"Tiqit purchase - Bought ticket"` | `"Tiqit Purchase"` | `"Tiqit purchase - Bought ticket"` (unchanged) |
| `"Other description"` | NULL | `"Other description"` (unchanged) |

#### Edge Cases Handled

- **Case-sensitive**: Only exact matches (e.g., "Banner - " not "banner - ")
- **Already processed**: Skips entries that already have meta_1 populated
- **No match**: Entries not matching any pattern are left unchanged

#### When to Use

Run this to:
- Categorize ledger entries by transaction type
- Enable filtering and reporting by meta_1 category
- Standardize description formats

## Running in Production (Gigalixir)

```bash
# Open remote console
gigalixir ps:remote_console

# Run diagnostics
Qlarius.Maintenance.SnapshotQueries.count_by_issue_type()

# Swap mobile numbers
Qlarius.Maintenance.SwapMobileNumbers.diagnose("user1", "user2")
Qlarius.Maintenance.SwapMobileNumbers.swap("user1", "user2")

# Split ledger entry descriptions
Qlarius.Maintenance.SplitLedgerEntryDescriptions.diagnose()
Qlarius.Maintenance.SplitLedgerEntryDescriptions.run()

# Fix NULL zip codes
Qlarius.Maintenance.FixNullSnapshotZipCodes.run()
```

## Adding New Maintenance Utilities

When creating new maintenance utilities:

1. **Create in this directory**: `lib/qlarius/maintenance/`
2. **Use clear naming**: e.g., `Fix*`, `Backfill*`, `Migrate*`
3. **Include diagnostics**: Always provide a `diagnose/0` function
4. **Support dry_run**: Allow testing without modifying data
5. **Batch processing**: Process large datasets in batches
6. **Comprehensive logging**: Log progress and issues
7. **Document here**: Update this README with usage examples

## Best Practices

### Before Running Any Fix

1. **Always diagnose first**: Run `diagnose()` to understand the scope
2. **Test with dry_run**: Use `dry_run: true` to verify logic
3. **Backup if needed**: For critical data, consider a backup first
4. **Monitor logs**: Watch for errors or warnings during execution
5. **Verify after**: Re-run diagnostics to confirm the fix worked

### Error Handling

All maintenance utilities should:
- Log warnings for skipped records (e.g., missing source data)
- Log errors for failed updates
- Continue processing other records on individual failures
- Return summary statistics of successes/failures

## Related Documentation

- **Snapshot Populations**: `lib/qlarius/jobs/SNAPSHOT_POPULATIONS_README.md`
- **Oban Workers**: `lib/qlarius/jobs/`
- **Me File Tags**: See `Qlarius.YouData.MeFiles.MeFileTag` schema
- **Target Populations**: See `Qlarius.Sponster.TargetPopulation` schema

