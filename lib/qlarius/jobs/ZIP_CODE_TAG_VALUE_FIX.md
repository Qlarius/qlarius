# Zip Code tag_value NULL Fix

## Problem

Home Zip Code snapshots were showing `null` for the tag_value instead of the actual zip code:

```elixir
# Wrong:
[4, "Home Zip Code", 1, [[58587, null, 10028]]]

# Correct:
[4, "Home Zip Code", 1, [[58587, "10028", 10028]]]
```

The structure is: `[parent_trait_id, "Parent Name", parent_display_order, [[child_trait_id, tag_value, child_display_order]]]`

## Root Cause

**File:** `lib/qlarius/accounts.ex` line 130  
**Function:** `build_me_file_tags/3`

When creating MeFileTag records during user registration, the zip code tag was being created with:

```elixir
# ❌ WRONG
tag_value: zip_trait.trait_name
```

This had two problems:

1. **trait_name can be NULL** - Some zip code traits in the database have NULL trait_name values
2. **Wrong data source** - Should use the actual user-entered zip code, not the trait name

The zip code flow works like this:

1. User enters zip code (e.g., "10028") in registration form
2. System looks up trait for that zip code using `get_zip_code_trait/2`
3. System stores `zip_lookup_input` (the actual zip "10028") in socket assigns
4. System stores `zip_lookup_trait` (the trait record with id 58587) in socket assigns
5. When creating user, only `zip_lookup_trait.id` was passed to attrs
6. **BUT** the actual zip code value `zip_lookup_input` was NOT passed! ❌
7. So `build_me_file_tags` tried to use `trait_name` as fallback, which was NULL

## Fix Applied

### Part 1: Pass zip code value in attrs

**File:** `lib/qlarius_web/live/accounts/registration_live.ex`  
**Function:** `create_user/1` (lines 483-507)

Added `home_zip` to attrs:

```elixir
attrs = %{
  alias: socket.assigns.alias,
  mobile_number: ...,
  role: "user",
  date_of_birth: date,
  sex_trait_id: socket.assigns.sex_trait_id,
  age_trait_id: socket.assigns.age_trait_id,
  zip_code_trait_id:
    if(socket.assigns.zip_lookup_valid, do: socket.assigns.zip_lookup_trait.id, else: nil),
  home_zip:                                        # ← NEW
    if(socket.assigns.zip_lookup_valid, do: socket.assigns.zip_lookup_input, else: nil)  # ← NEW
}
```

Now the actual user-entered zip code is passed to `register_new_user/1`.

### Part 2: Use actual zip code value for tag_value

**File:** `lib/qlarius/accounts.ex`  
**Function:** `build_me_file_tags/3` (lines 122-138)

Changed to use `attrs[:home_zip]`:

```elixir
# ✅ CORRECT
tags =
  if attrs[:zip_code_trait_id] && attrs[:home_zip] do
    [
      Qlarius.YouData.MeFiles.MeFileTag.changeset(%Qlarius.YouData.MeFiles.MeFileTag{}, %{
        me_file_id: me_file_id,
        trait_id: attrs[:zip_code_trait_id],
        tag_value: attrs[:home_zip],  # ← Use actual zip code from user input
        added_by: user_id,
        modified_by: user_id
      })
      | tags
    ]
  else
    tags
  end
```

## Impact

### Before Fix
- ❌ New registrations: zip code tag_value = NULL
- ❌ Snapshots show: `[58587, null, 10028]`
- ❌ Zip code data lost/unusable

### After Fix
- ✅ New registrations: zip code tag_value = "10028"
- ✅ Snapshots show: `[58587, "10028", 10028]`
- ✅ Zip code data properly stored

## Existing Bad Data

### How to Find Records with NULL zip code tag_value

```elixir
# In IEx console
alias Qlarius.Repo
alias Qlarius.YouData.MeFiles.MeFileTag
alias Qlarius.YouData.Traits.Trait
import Ecto.Query

# Count me_file_tags with NULL tag_value for Home Zip Code parent trait
Repo.one(
  from mft in MeFileTag,
    join: t in Trait,
    on: mft.trait_id == t.id,
    where: t.parent_trait_id == 4 and is_nil(mft.tag_value),
    select: count(mft.id)
)
```

### How to Fix Existing Records

The fix is more complex because we need to determine the actual zip code from the trait_id:

```elixir
# In IEx console
alias Qlarius.Repo
alias Qlarius.YouData.MeFiles.MeFileTag
alias Qlarius.YouData.Traits.Trait
import Ecto.Query

# Find and fix NULL zip code tag_values
Repo.transaction(fn ->
  tags_with_null =
    from(mft in MeFileTag,
      join: t in Trait,
      on: mft.trait_id == t.id,
      where: t.parent_trait_id == 4 and is_nil(mft.tag_value),
      preload: [:trait],
      select: mft
    )
    |> Repo.all()
  
  Enum.each(tags_with_null, fn tag ->
    # The trait_name SHOULD contain the zip code
    # If it's NULL, we can try to find it from the trait record
    zip_code = tag.trait.trait_name || tag.trait.meta_1
    
    if zip_code do
      from(mft in MeFileTag, where: mft.id == ^tag.id)
      |> Repo.update_all(set: [tag_value: zip_code])
    else
      IO.puts("Cannot fix tag ID #{tag.id} - trait #{tag.trait_id} has no name or meta_1")
    end
  end)
end)
```

**Note:** This assumes the zip code is stored in either `trait_name` or `meta_1` on the Trait record. If neither contains the zip code, the data cannot be recovered and those records would need manual review.

### Better Approach: One-Time Migration Worker

For production, create a worker similar to `FixIncorrectSnapshotFormatsWorker`:

```elixir
defmodule Qlarius.Jobs.FixNullZipCodeTagValuesWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3
  
  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.YouData.MeFiles.MeFileTag
  alias Qlarius.YouData.Traits.Trait
  
  @impl true
  def perform(%Oban.Job{args: _args}) do
    require Logger
    Logger.info("FixNullZipCodeTagValuesWorker: Starting")
    
    # Find MeFileTag records with NULL tag_value for Home Zip Code parent trait
    tags_to_fix =
      from(mft in MeFileTag,
        join: t in Trait,
        on: mft.trait_id == t.id,
        where: t.parent_trait_id == 4 and is_nil(mft.tag_value),
        preload: [:trait],
        select: mft
      )
      |> Repo.all()
    
    total = length(tags_to_fix)
    Logger.info("FixNullZipCodeTagValuesWorker: Found #{total} tags with NULL tag_value")
    
    fixed_count =
      Repo.transaction(fn ->
        Enum.reduce(tags_to_fix, 0, fn tag, count ->
          # Try to get zip code from trait_name first, then meta_1
          zip_code = tag.trait.trait_name || tag.trait.meta_1
          
          if zip_code && String.match?(zip_code, ~r/^\d{5}$/) do
            {updated, _} =
              from(mft in MeFileTag, where: mft.id == ^tag.id)
              |> Repo.update_all(set: [tag_value: zip_code])
            
            count + updated
          else
            Logger.warning(
              "Cannot fix tag ID #{tag.id} - trait #{tag.trait_id} has no valid zip code (trait_name: #{inspect(tag.trait.trait_name)}, meta_1: #{inspect(tag.trait.meta_1)})"
            )
            
            count
          end
        end)
      end)
    
    case fixed_count do
      {:ok, count} ->
        Logger.info("FixNullZipCodeTagValuesWorker: ✅ Fixed #{count} of #{total} tags")
        
        # After fixing MeFileTag records, regenerate snapshots
        # The BackfillMissingSnapshotsWorker will pick these up in its next run
        :ok
      
      {:error, reason} ->
        Logger.error("FixNullZipCodeTagValuesWorker: ❌ Transaction failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

**To run:**
```elixir
Qlarius.Jobs.FixNullZipCodeTagValuesWorker.new(%{})
|> Oban.insert()
```

## Prevention

This fix ensures that future registrations will:
1. ✅ Pass the actual user-entered zip code to `register_new_user/1`
2. ✅ Store the zip code in `tag_value` field
3. ✅ Generate snapshots with proper zip code values

The `BackfillMissingSnapshotsWorker` (runs hourly) will automatically regenerate snapshots for any populations, offers, or ad_events that were affected, pulling the corrected `tag_value` from the fixed `me_file_tags` records.

## Testing

### Verify Fix Works for New Registrations

1. Complete a new registration with zip code "12345"
2. Check the me_file_tag record:
   ```elixir
   alias Qlarius.Repo
   alias Qlarius.YouData.MeFiles.MeFileTag
   import Ecto.Query
   
   # Get the most recent zip code tag
   tag = Repo.one(
     from mft in MeFileTag,
       join: t in Trait,
       on: mft.trait_id == t.id,
       where: t.parent_trait_id == 4,
       order_by: [desc: mft.id],
       limit: 1,
       preload: [:trait]
   )
   
   IO.inspect(tag.tag_value, label: "tag_value")
   # Should output: tag_value: "12345"
   ```

3. Check the snapshot:
   ```elixir
   alias Qlarius.Sponster.Campaigns.TargetPopulation
   
   # Find a population for that me_file
   pop = Repo.get_by(TargetPopulation, me_file_id: tag.me_file_id)
   
   IO.inspect(pop.matching_tags_snapshot, label: "snapshot")
   # Should show: [4, "Home Zip Code", 1, [[trait_id, "12345", display_order]]]
   ```

## Related Files

- `lib/qlarius_web/live/accounts/registration_live.ex` - Registration form (passes home_zip)
- `lib/qlarius/accounts.ex` - User creation (uses home_zip for tag_value)
- `lib/qlarius_web/live/helpers/zip_code_lookup.ex` - Zip code validation
- `lib/qlarius/youdata/mefiles/me_file_tag.ex` - MeFileTag schema
- `lib/qlarius/youdata/traits/trait.ex` - Trait schema
- `lib/qlarius/jobs/snapshot_band_populations_worker.ex` - Snapshot generation
- `lib/qlarius/jobs/backfill_missing_snapshots_worker.ex` - Snapshot correction

