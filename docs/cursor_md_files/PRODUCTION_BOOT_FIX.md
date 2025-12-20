# Production Boot Issue Fix

## Problem

The application was crashing during boot in production with:

```
ArgumentError: the table identifier does not refer to an existing ETS table
    (stdlib 6.0) :ets.lookup(:secrets_cache, :twilio_config)
    (qlarius 0.1.0) lib/qlarius/secrets.ex:129: Qlarius.Secrets.get_from_cache/1
    /app/releases/0.1.0/runtime.exs:139: (file)
```

## Root Cause

**Boot Order Issue**: `config/runtime.exs` was trying to fetch secrets using the cache **before** the application (and the `Qlarius.Secrets` GenServer that creates the ETS cache) had started.

### Why This Happened

1. `runtime.exs` executes during boot, before the application supervision tree starts
2. `Qlarius.Secrets.fetch_twilio_config()` tried to use the ETS cache
3. The `:secrets_cache` ETS table didn't exist yet (created by GenServer's `init/1`)
4. `:ets.lookup()` raised `ArgumentError`

## The Fix

### 1. Created No-Cache Functions

Added boot-safe functions that don't rely on the cache:

```elixir
# lib/qlarius/secrets.ex
def fetch_twilio_config_no_cache do
  fetch_twilio_config_from_source()
end

def fetch_cloak_key_no_cache do
  fetch_cloak_key_from_source()
end
```

### 2. Updated runtime.exs

Changed to use the no-cache versions during boot:

```elixir
# config/runtime.exs (line ~139)
twilio_config = Qlarius.Secrets.fetch_twilio_config_no_cache()
cloak_key = Qlarius.Secrets.fetch_cloak_key_no_cache()
```

### 3. Made Secrets a Proper GenServer

Converted `Qlarius.Secrets` from a module with an `init/0` function to a supervised GenServer:

```elixir
# lib/qlarius/secrets.ex
defmodule Qlarius.Secrets do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(:secrets_cache, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
```

### 4. Added to Supervision Tree

```elixir
# lib/qlarius/application.ex
children = [
  # ...
  Qlarius.Secrets,  # Added this
  # ...
]
```

### 5. Added Error Handling

Made cache functions resilient to missing ETS table:

```elixir
defp get_from_cache(key) do
  try do
    # ... ETS lookup
  rescue
    ArgumentError -> :miss  # Graceful fallback if table doesn't exist
  end
end
```

## How It Works Now

### Boot Sequence

1. **Runtime Config Phase** (`runtime.exs` executes)
   - Calls `fetch_twilio_config_no_cache()` and `fetch_cloak_key_no_cache()`
   - Fetches directly from AWS Parameter Store (no cache)
   - Configures Twilio and Cloak modules

2. **Application Start** (supervision tree starts)
   - `Qlarius.Secrets` GenServer starts
   - Creates `:secrets_cache` ETS table
   - Ready for runtime caching

3. **Runtime** (after boot)
   - Runtime code can use `fetch_twilio_config()` (with cache)
   - Cache provides 5-minute TTL for Twilio config, 1-hour for Cloak key
   - Reduces AWS API calls

### Cache Strategy

```elixir
# During boot (runtime.exs)
config = Qlarius.Secrets.fetch_twilio_config_no_cache()  # Direct fetch, no cache

# During runtime (LiveViews, controllers, etc.)
config = Qlarius.Secrets.fetch_twilio_config()  # Uses cache if available
```

## Files Changed

1. `lib/qlarius/secrets.ex` - Made GenServer, added no-cache functions
2. `config/runtime.exs` - Use no-cache functions during boot
3. `lib/qlarius/application.ex` - Add Secrets to supervision tree
4. `AWS_SECRETS_SETUP.md` - Complete AWS setup guide (NEW)

## Testing the Fix

### Local Test (with AWS credentials)

```bash
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret

# Test boot-time fetch (no cache)
mix run -e "IO.inspect(Qlarius.Secrets.fetch_twilio_config_no_cache())"

# Start app and test runtime fetch (with cache)
iex -S mix
iex> Qlarius.Secrets.fetch_twilio_config()
```

### Production Test

```bash
# Deploy and watch logs
kubectl logs -f deployment/qlarius | grep -i "secrets\|twilio\|cloak"

# Should see:
# "Fetching Twilio credentials from AWS Parameter Store"
# "Secrets cache initialized"
# No errors about ETS table
```

## Deployment Steps

1. **Commit and push changes**:
   ```bash
   git add -A
   git commit -m "Fix production boot issue with secrets cache"
   git push origin main
   ```

2. **Build and deploy**:
   ```bash
   # Your CI/CD will build the new image
   # Or manually:
   docker build -t your-registry/qlarius:latest .
   docker push your-registry/qlarius:latest
   kubectl rollout restart deployment/qlarius
   ```

3. **Verify boot successful**:
   ```bash
   kubectl get pods
   kubectl logs deployment/qlarius --tail=50
   ```

4. **Test authentication**:
   - Visit `/register` in production
   - Enter mobile number and request SMS code
   - Verify Twilio is working

## Rollback Plan

If issues persist:

```bash
# Rollback to previous version
kubectl rollout undo deployment/qlarius

# Check rollback status
kubectl rollout status deployment/qlarius
```

## Why This Won't Happen Again

1. **Boot vs Runtime Separation**: Clear distinction between boot-time (no cache) and runtime (cached) functions
2. **Supervision**: Secrets GenServer is now properly supervised
3. **Error Handling**: Cache functions gracefully handle missing ETS table
4. **Documentation**: AWS setup guide prevents configuration issues

## Related Documentation

- `AWS_SECRETS_SETUP.md` - Complete AWS Parameter Store setup
- `docs/phone_auth_implementation.md` - Twilio integration details
- `docs/carrier_validation_testing.md` - Testing phone verification

## Summary

**Before**: Tried to use cache before it existed → crash  
**After**: Boot uses direct fetch, runtime uses cache → stable ✅

The fix ensures secrets are always available during boot while maintaining the performance benefits of caching during runtime.

