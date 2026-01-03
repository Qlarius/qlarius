# CRITICAL BUG FIX: Missing Mobile Numbers During Registration

## Issue

User ID **200393** (alias: `happy-slough-8114`) registered successfully but their mobile number was not saved to the database. This prevents them from logging back in because the authentication system cannot find their phone number.

## Root Cause

**File**: `lib/qlarius/accounts.ex` line 33

**Bug**: The `register_new_user/1` function was calling the wrong changeset:

```elixir
# WRONG (before fix)
|> Ecto.Multi.insert(:user, User.changeset(%User{}, attrs))

# CORRECT (after fix)
|> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, attrs))
```

**Why this caused the problem**:
- `User.changeset/2` only handles `:alias` and `:role` fields
- `User.registration_changeset/2` includes `maybe_encrypt_mobile_number/2` which actually encrypts and saves the mobile number
- Without calling the registration changeset, the mobile number was silently ignored during registration

## Impact

Any users who registered between the time this bug was introduced and now will have:
- `mobile_number_encrypted` = `NULL`
- `mobile_number_hash` = `NULL`
- Unable to log in with their phone number

## Fix Applied

### 1. Code Fix
✅ Updated `lib/qlarius/accounts.ex` to use `User.registration_changeset/2`

### 2. Maintenance Script Created
✅ Created `lib/qlarius/maintenance/fix_missing_mobile_numbers.ex` to fix affected users

## Recovering Affected Users

### Step 1: Find Affected Users

```elixir
# In IEx or Gigalixir console
Qlarius.Maintenance.FixMissingMobileNumbers.find_users_without_mobile()
```

### Step 2: Fix User 200393

**You will need to contact the user to get their phone number**, then run:

```elixir
# Dry run first (to test)
Qlarius.Maintenance.FixMissingMobileNumbers.fix_user_dry_run(200393, "+1XXXXXXXXXX")

# If dry run looks good, run the actual fix
Qlarius.Maintenance.FixMissingMobileNumbers.fix_user(200393, "+1XXXXXXXXXX")
```

Replace `"+1XXXXXXXXXX"` with the user's actual phone number in E.164 format (e.g., `"+15551234567"`).

### Step 3: Verify Fix

```elixir
# Check the user record
user = Qlarius.Repo.get!(Qlarius.Accounts.User, 200393)
IO.inspect(user.mobile_number_encrypted)  # Should show the phone number
IO.inspect(user.mobile_number_hash)       # Should show a 32-byte binary
```

## Testing the Fix

### For New Registrations

1. Register a new test user through the UI
2. Check the database to confirm mobile number is saved:

```sql
SELECT id, alias, mobile_number_encrypted, mobile_number_hash 
FROM users 
WHERE alias = 'test-user-alias';
```

3. Try logging in with the test user's phone number

## Files Changed

- ✅ `lib/qlarius/accounts.ex` - Fixed registration to use correct changeset
- ✅ `lib/qlarius/maintenance/fix_missing_mobile_numbers.ex` - New recovery script
- ✅ `lib/qlarius/maintenance/README.md` - Updated documentation

## Prevention

This bug is now fixed. All future registrations will correctly save mobile numbers. The maintenance script is available for any historical cases that need to be corrected.

## Action Items

- [ ] Deploy the fix to production
- [ ] Run `find_users_without_mobile()` to identify all affected users
- [ ] Contact affected users to get their phone numbers
- [ ] Run `fix_user()` for each affected user
- [ ] Test new registration flow to confirm fix works
- [ ] Monitor for any additional reports of login issues

---

**Date**: 2026-01-03
**Severity**: CRITICAL
**Status**: FIXED (code) + RECOVERY SCRIPT AVAILABLE
