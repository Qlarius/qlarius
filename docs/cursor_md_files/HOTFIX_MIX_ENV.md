# Hotfix: Remove Mix.env() from Production Code

## Problem

The app was failing to boot on Gigalixir with:

```
UndefinedFunctionError: function Mix.env/0 is undefined (module Mix is not available)
    Mix.env()
    (qlarius 0.1.0) lib/qlarius/secrets.ex:78: Qlarius.Secrets.fetch_twilio_config_from_source/0
```

## Root Cause

**`Mix` module is not available in production releases.**

In production, Elixir releases (used by Gigalixir, Fly.io, etc.) strip out the `Mix` module to reduce the release size. Our code was checking `Mix.env() == :prod` which caused the crash.

## The Fix

### Before (Broken)
```elixir
defp fetch_twilio_config_from_source do
  if Mix.env() == :prod && use_aws_ssm?() do  # ❌ Mix not available in releases
    fetch_from_aws_ssm()
  else
    fetch_from_env_vars()
  end
end
```

### After (Fixed)
```elixir
defp fetch_twilio_config_from_source do
  if use_aws_ssm?() do  # ✅ Just check platform, no Mix.env()
    fetch_from_aws_ssm()
  else
    fetch_from_env_vars()
  end
end
```

### Updated Platform Detection

```elixir
defp use_aws_ssm? do
  # Use AWS SSM only if:
  # 1. Not on Gigalixir (GIGALIXIR_APP_NAME not set)
  # 2. Not on Heroku (DYNO not set)
  # 3. AWS region is configured (AWS_REGION set)
  !System.get_env("GIGALIXIR_APP_NAME") && 
    !System.get_env("DYNO") && 
    System.get_env("AWS_REGION")
end
```

## How It Works Now

### On Gigalixir:
- `GIGALIXIR_APP_NAME` is set → `use_aws_ssm?()` returns `false`
- Uses environment variables for all secrets ✅

### On AWS EKS/ECS:
- `AWS_REGION` is set, no `GIGALIXIR_APP_NAME` → `use_aws_ssm?()` returns `true`
- Uses AWS Parameter Store for secrets ✅

### In Local Development:
- No platform env vars set → `use_aws_ssm?()` returns `false`
- Uses environment variables ✅

## Key Lesson

**Never use `Mix.env()` in code that runs in production releases.**

### Safe Alternatives:

1. **Environment variables** (best for runtime detection):
   ```elixir
   System.get_env("RELEASE_NODE")  # Set in releases
   System.get_env("MIX_ENV")       # If explicitly set
   ```

2. **Compile-time config** (for build-time decisions):
   ```elixir
   # In config/prod.exs
   config :qlarius, :use_aws_ssm, true
   
   # In code
   Application.get_env(:qlarius, :use_aws_ssm, false)
   ```

3. **Platform detection** (what we're doing now):
   ```elixir
   System.get_env("GIGALIXIR_APP_NAME")  # On Gigalixir
   System.get_env("DYNO")                # On Heroku
   System.get_env("AWS_REGION")          # On AWS
   System.get_env("FLY_APP_NAME")        # On Fly.io
   ```

## Files Changed

- `lib/qlarius/secrets.ex`: Removed all `Mix.env()` checks

## Testing

```bash
# Deploy to Gigalixir
git push gigalixir main

# Watch logs
gigalixir logs -f

# Should see:
# ✅ "Fetching Twilio credentials from environment variables"
# ✅ "Secrets cache initialized"
# ✅ No Mix.env() errors
```

## Related Issues

This is a common gotcha when moving from development to production:
- Works in `iex -S mix` (Mix available)
- Crashes in releases (Mix stripped out)

Always test in a release environment before deploying!

```bash
# Test locally with a release build
MIX_ENV=prod mix release
_build/prod/rel/qlarius/bin/qlarius start
```

