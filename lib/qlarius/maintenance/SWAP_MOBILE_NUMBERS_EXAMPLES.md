# Mobile Number Swap - Usage Examples

## Quick Start

```elixir
# In IEx or Gigalixir console
alias Qlarius.Maintenance.SwapMobileNumbers

# Step 1: Diagnose - see what will happen (no changes)
SwapMobileNumbers.diagnose("alice", "bob")

# Step 2: Swap - perform the actual swap
{:ok, result} = SwapMobileNumbers.swap("alice", "bob")

# Step 3: Verify - confirm it worked
SwapMobileNumbers.verify_swap("alice", "bob", "+15559876543", "+15551234567")
```

## Detailed Example Session

```elixir
# === Example: Swapping mobile numbers between two users ===

iex> alias Qlarius.Maintenance.SwapMobileNumbers

# First, let's see what we're working with
iex> SwapMobileNumbers.diagnose("john_doe", "jane_smith")

=== Mobile Number Swap Diagnosis ===
User 1 alias: john_doe
User 2 alias: jane_smith

--- User 1: john_doe (ID: 123) ---
Mobile Number: +15551234567
Encrypted: <24 bytes>
Hash: <32 bytes>
Verified: Yes (2024-12-20 10:30:00 UTC)

--- User 2: jane_smith (ID: 456) ---
Mobile Number: +15559876543
Encrypted: <24 bytes>
Hash: <32 bytes>
Verified: No

--- After Swap Preview ---
User 1 (john_doe) would get: +15559876543
User 2 (jane_smith) would get: +15551234567

# Looks good! Let's perform the swap
iex> {:ok, result} = SwapMobileNumbers.swap("john_doe", "jane_smith")

=== Starting mobile number swap ===
User 1 alias: john_doe
User 2 alias: jane_smith
Found user: john_doe (ID: 123)
Found user: jane_smith (ID: 456)
Starting transaction to swap mobile numbers...
User 1 (john_doe) current mobile: +15551234567
User 2 (jane_smith) current mobile: +15559876543
Updated user 2 (jane_smith) mobile to: +15551234567
Updated user 1 (john_doe) mobile to: +15559876543
Swap successful, committing transaction
=== Mobile number swap completed successfully ===

{:ok,
 %{
   user1: %Qlarius.Accounts.User{
     id: 123,
     alias: "john_doe",
     mobile_number: "+15559876543",
     phone_verified_at: nil
   },
   user2: %Qlarius.Accounts.User{
     id: 456,
     alias: "jane_smith",
     mobile_number: "+15551234567",
     phone_verified_at: ~U[2024-12-20 10:30:00Z]
   },
   summary: %{
     user1_alias: "john_doe",
     user1_new_mobile: "+15559876543",
     user1_verified: false,
     user2_alias: "jane_smith",
     user2_new_mobile: "+15551234567",
     user2_verified: true
   }
 }}

# Verify it worked
iex> SwapMobileNumbers.verify_swap(
  "john_doe", 
  "jane_smith",
  "+15559876543",
  "+15551234567"
)

=== Verification Results ===
✓ john_doe: +15559876543 (expected: +15559876543)
✓ jane_smith: +15551234567 (expected: +15551234567)

✓ All mobile numbers match expected values
:ok
```

## Error Handling Examples

### User Not Found

```elixir
iex> SwapMobileNumbers.swap("alice", "nonexistent_user")

Found user: alice (ID: 123)
=== Mobile number swap failed: {:user_not_found, "User with alias 'nonexistent_user' not found"} ===

{:error, :user_not_found, "User with alias 'nonexistent_user' not found"}
```

### Same User

```elixir
iex> SwapMobileNumbers.swap("alice", "alice")

Found user: alice (ID: 123)
Found user: alice (ID: 123)
=== Mobile number swap failed: {:same_user, "Cannot swap mobile numbers for the same user"} ===

{:error, :same_user, "Cannot swap mobile numbers for the same user"}
```

## Via Mix Command

```bash
# From the command line (useful for scripts or automation)
mix run -e 'Qlarius.Maintenance.SwapMobileNumbers.swap("alice", "bob")'

# Just diagnose
mix run -e 'Qlarius.Maintenance.SwapMobileNumbers.diagnose("alice", "bob")'
```

## Real-World Use Cases

### 1. User Wants to Merge Accounts

User has two accounts but wants to use a verified phone from Account B on Account A:

```elixir
# User's verified number is on "bob_backup" but they want it on "bob_main"
SwapMobileNumbers.diagnose("bob_main", "bob_backup")
SwapMobileNumbers.swap("bob_main", "bob_backup")
# Now "bob_main" has the verified number
```

### 2. Porting Number to New Account

User created a new account but wants their old verified number:

```elixir
SwapMobileNumbers.swap("new_account", "old_account")
# Now new_account has the verified number from old_account
```

### 3. Data Correction

Mobile numbers were accidentally assigned to wrong users:

```elixir
# Alice and Bob's numbers got mixed up during data import
SwapMobileNumbers.diagnose("alice", "bob")
SwapMobileNumbers.swap("alice", "bob")
# Numbers are now with the correct users
```

## Production Deployment (Gigalixir)

```bash
# Step 1: Open remote console
gigalixir ps:remote_console

# Step 2: Run the script
iex> alias Qlarius.Maintenance.SwapMobileNumbers
iex> SwapMobileNumbers.diagnose("user1", "user2")
iex> SwapMobileNumbers.swap("user1", "user2")
```

## Important Notes

1. **Transaction Safety**: The entire swap happens in a database transaction. If any part fails, everything rolls back.

2. **Verification Status Swaps Too**: The `phone_verified_at` timestamp moves with the mobile number, so verified status follows the number.

3. **Encrypted Data**: All encrypted fields and hashes are swapped together to maintain data integrity.

4. **No Deletion**: No data is deleted during the swap - everything is just moved between users.

5. **Logging**: All operations are logged with timestamps and user info for audit trails.

## Troubleshooting

### Transaction Rollback

If you see a transaction rollback error, check:
- Database connectivity
- Unique constraints (shouldn't be an issue with swap, but check logs)
- User exists and hasn't been deleted mid-transaction

### Verification Failed

If `verify_swap` fails:
- Phone numbers might have been changed by another process
- Re-run `diagnose` to see current state
- Check application logs for any concurrent updates

### Need to Swap Back

Just run the swap again with aliases reversed:

```elixir
# Undo the swap
SwapMobileNumbers.swap("bob", "alice")  # Reverses the previous swap
```

