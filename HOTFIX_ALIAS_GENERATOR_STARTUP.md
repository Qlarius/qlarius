# Hotfix: AliasGenerator Graceful Startup

## Problem

App was crashing on startup with:

```
Application qlarius exited: shutdown: failed to start child: Qlarius.Accounts.AliasGenerator
** (Postgrex.Error) ERROR 42P01 (undefined_table) relation "alias_words" does not exist
```

**Chicken-and-egg problem:**
1. App tries to start
2. `AliasGenerator` GenServer loads words from `alias_words` table
3. Table doesn't exist (migrations not run)
4. App crashes
5. Can't run migrations because app won't start! 🔄

## The Fix

Made `AliasGenerator` resilient to missing database table by:
1. Wrapping database queries in try-rescue
2. Using fallback hardcoded words if table doesn't exist
3. Logging a warning instead of crashing

### Changes

**Before (crashes):**
```elixir
def init(_state) do
  :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
  load_words()  # ❌ Crashes if table doesn't exist
  {:ok, %{}}
end
```

**After (graceful):**
```elixir
def init(_state) do
  :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
  
  case load_words() do
    :ok -> 
      {:ok, %{}}
    {:error, :table_not_found} ->
      Logger.warning("alias_words table not found - using fallback words")
      load_fallback_words()  # ✅ Uses hardcoded words
      {:ok, %{}}
  end
end
```

### Error Handling in load_words()

```elixir
defp load_words do
  try do
    adjectives = Repo.all(from w in AliasWord, ...)
    nouns = Repo.all(from w in AliasWord, ...)
    # ... insert into ETS
    :ok
  rescue
    Postgrex.Error ->
      Logger.warning("Failed to load alias words - table may not exist yet")
      {:error, :table_not_found}
  end
end
```

### Fallback Words

Added `load_fallback_words/0` with 50 adjectives and 50 nouns:
- Adjectives: "agile", "ancient", "brave", "calm", "clever", ...
- Nouns: "mountain", "river", "ocean", "forest", "meadow", ...

These are loaded into the ETS cache if the database table doesn't exist yet.

## Boot Flow Now

### First Deploy (before migrations):
1. App starts
2. `AliasGenerator` tries to load from DB
3. Table doesn't exist → rescue block catches error
4. Loads 50 fallback adjectives and nouns ✅
5. App starts successfully ✅
6. Migrations can now be run!

### After Migrations:
1. App starts
2. `AliasGenerator` loads from DB
3. Table exists with 500 adjectives and 500 nouns ✅
4. Full word list available

### After Seeding:
1. Admin can manage words via `/admin/alias_words`
2. Words stored in database
3. Cache refreshed on app restart or manual refresh

## Deploy Process

### 1. Deploy the Fix
```bash
git push gigalixir main
```

App will now start successfully with fallback words!

### 2. Run Migrations
```bash
gigalixir run mix ecto.migrate
```

This creates the `alias_words` table.

### 3. Seed Alias Words
```bash
gigalixir run mix run priv/repo/seeds_alias_words.exs
```

This populates the table with 500 adjectives and 500 nouns.

### 4. Restart App (optional)
```bash
gigalixir ps:restart
```

This reloads words from the database (or will happen on next deploy).

## Why This Fix Works

**Resilient Startup Pattern:**
- App doesn't depend on database schema being up-to-date
- Can start even with missing tables
- Provides basic functionality with fallback data
- Automatically uses full dataset when available

**No More Chicken-and-Egg:**
- App starts → migrations can run → full data available
- Instead of: migrations needed → app won't start → can't run migrations

## Files Changed

- `lib/qlarius/accounts/alias_generator.ex`:
  - Added error handling in `init/1`
  - Made `load_words/0` return `:ok` or `{:error, :table_not_found}`
  - Added `load_fallback_words/0` with hardcoded words
  - Updated `handle_call(:refresh, ...)` to handle errors

## Testing

### Test Locally Without Migrations

```bash
# Drop the table to simulate fresh deploy
mix ecto.rollback --step 1

# Start the app - should work with fallback words
iex -S mix

# Generate aliases - should work
iex> Qlarius.Accounts.AliasGenerator.generate_base_names()
["brave-mountain-1234", "calm-river-5678", ...]

# Run migrations
mix ecto.migrate

# Seed
mix run priv/repo/seeds_alias_words.exs

# Restart or refresh cache
iex> Qlarius.Accounts.AliasGenerator.refresh_cache()
# Now using full 500-word lists
```

### In Production

After deploying this fix:

```bash
# Watch logs - should see:
gigalixir logs -f
# "alias_words table not found - using fallback words until migrations are run"
# "Loaded 50 fallback adjectives and 50 fallback nouns"

# App should be healthy
gigalixir ps

# Run migrations
gigalixir run mix ecto.migrate

# Seed words
gigalixir run mix run priv/repo/seeds_alias_words.exs

# Restart to use full word list
gigalixir ps:restart
```

## Future Improvements

Could add:
1. Automatic retry: Check for table periodically and reload from DB when available
2. Better fallback: More diverse word list (current 50 each, could expand)
3. Admin notification: Alert admins if running on fallback words
4. Health check: Include in `/health` endpoint if using fallback vs. full data

## Related Issues

This pattern should be used for any GenServer that loads data during startup:
- Always handle missing tables gracefully
- Provide fallback/default behavior
- Log warnings, don't crash
- Allow app to start even with incomplete schema

## Summary

**Problem**: App crashed on startup because it tried to load alias words before migrations were run.

**Solution**: Handle missing table gracefully by using hardcoded fallback words during startup.

**Result**: App starts successfully → migrations can be run → full data becomes available. ✅

