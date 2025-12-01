# User Registration Flow

## Overview

A comprehensive 4-step registration flow for new users and admin-created proxy users. The system ensures all users have complete and valid MeFile data before accessing the application.

## Implementation Components

### 1. Database & Schema Changes

**User Schema (`lib/qlarius/accounts/user.ex`)**
- Updated changeset to include: `alias`, `mobile_number`, `auth_provider_id`, `role`
- `alias` is required and unique (serves as display name)
- `username` is optional (kept blank for regular users, used for admin purposes with proxy users)
- `mobile_number` is optional for proxy users

### 2. Context Functions

**Accounts Context (`lib/qlarius/accounts.ex`)**
- `alias_available?(alias)` - Check alias uniqueness in real-time
- `register_new_user(attrs)` - Complete registration transaction that creates:
  - User record
  - MeFile record
  - LedgerHeader (initial balance $0.00)
  - MeFileTag records (Sex, Age, Home Zip if provided)
  - ProxyUser relationship (if created by admin)
- `activate_proxy_user(true_user_id, proxy_user_id)` - Auto-activate new proxy users

**MeFiles Context (`lib/qlarius/youdata/mefiles.ex`)**
- `is_initialized?(me_file)` - Validates MeFile has required tags (Sex, Age, Birthdate)
- `calculate_age(date_of_birth)` - Calculate age from birthdate
- `get_age_trait_for_age(age)` - Get the appropriate age range trait (18-24, 25-34, etc.)
- `update_age_tags_for_birthdate(date)` - Update age tags for users with matching birthday

### 3. Registration LiveView

**Route:** `/register`

**Location:** `lib/qlarius_web/live/accounts/registration_live.ex`

**Features:**
- DaisyUI Steps component for progress indication
- Dark mode support
- Real-time validation
- Two modes: regular user and proxy user creation

**Steps:**

#### Step 1: Mobile Number
- Regular users: Placeholder for future authentication integration
- Proxy users: Optional field
- Stored as both `mobile_number` and `auth_provider_id`

#### Step 2: Alias
- Required, must be unique
- Real-time validation with error messages
- Serves as display name/username

#### Step 3: Core MeFile Data
- **Sex (Biological)** - Required, dropdown from Trait ID 1 child options
- **Birthdate** - Required, three text inputs (YYYY, MM, DD)
  - Shows calculated age badge when valid
  - Must be 18+ years old
  - Age automatically mapped to appropriate trait (18-24, 25-34, etc.)
- **Home Zip Code** - Optional but encouraged
  - Reuses existing `ZipCodeLookup` helper
  - Shows validation badge (STANDARD zip codes only)

#### Step 4: Confirmation
- Summary display of all entered information
- Required checkbox: "I confirm my birthdate and sex are correct and understand they cannot be changed"
- Creates all records in single transaction on submit

### 4. Proxy User Creation

**Location:** `lib/qlarius_web/live/proxy_users_live.ex`

**Flow:**
1. Admin clicks "Add Proxy User" button on `/proxy_users` page
2. Modal opens with three fields:
   - Alias (required, validated for uniqueness)
   - Username (required, for admin purposes)
   - Mobile Number (optional)
3. On submit, stores data in flash and redirects to `/register?mode=proxy`
4. Registration flow starts at Step 3 (Steps 1-2 shown as complete)
5. After completion:
   - New proxy user is auto-activated
   - Admin is redirected back to `/proxy_users` page

### 5. Route Protection

**Location:** `lib/qlarius_web/user_auth.ex`

**On Mount Hook:** `:require_initialized_mefile`

**Applied to all authenticated routes:**
- Checks if user has a MeFile with required tags (Sex, Age, Birthdate)
- Redirects to `/register` if incomplete
- Works with both direct users and active proxy users
- Registration route excluded from protection

**Protected Routes:**
- `/` (home)
- `/users/settings`
- `/wallet`
- `/ads`
- `/proxy_users`
- `/me_file`
- `/me_file_builder`

### 6. Age Update Worker

**Location:** `lib/qlarius/jobs/update_age_tags_worker.ex`

**Scheduled:** Daily at midnight UTC (via OBAN cron)

**Function:** Updates age tags for users whose birthday is today

**Usage:**
```elixir
# Automatic daily run at midnight UTC
# Manual run for today:
Qlarius.Jobs.UpdateAgeTagsWorker.new(%{}) |> Oban.insert()

# Manual run for specific date:
Qlarius.Jobs.UpdateAgeTagsWorker.new(%{"date" => "2025-11-29"}) |> Oban.insert()

# Manual run for date range (backfill):
Qlarius.Jobs.UpdateAgeTagsWorker.new(%{
  "start_date" => "2025-01-01",
  "end_date" => "2025-01-31"
}) |> Oban.insert()
```

### 7. Configuration

**OBAN Cron (`config/config.exs`)**
```elixir
{"0 0 * * *", Qlarius.Jobs.UpdateAgeTagsWorker}
```

## Data Flow

### Regular User Registration
1. User visits `/register`
2. Completes Steps 1-4
3. Transaction creates: User → MeFile → LedgerHeader → Tags
4. User redirected to home page

### Admin Creating Proxy User
1. Admin on `/proxy_users` clicks "Add Proxy User"
2. Modal: enters Alias + Username (+ optional Mobile)
3. Redirects to `/register?mode=proxy` with data in flash
4. Admin completes Step 3 (Core MeFile Data)
5. Confirms in Step 4
6. Transaction creates: User → ProxyUser → MeFile → LedgerHeader → Tags
7. New proxy user auto-activated
8. Admin redirected back to `/proxy_users`

## Required Traits

- **Sex (Biological)** - Parent Trait ID: 1
  - Child traits: Male, Female (queried dynamically)
- **Age** - Parent Trait ID: 93
  - Age ranges: 18-24, 25-34, 35-44, 45-54, 55-64, 65-74, 75+
- **Home Zip Code** - Parent Trait ID: 4 (optional)
  - 44,000+ child traits (STANDARD type zip codes)

## Immutable Fields

Once set during registration, these fields **cannot be changed**:
- Birthdate (stored in `me_files.date_of_birth`)
- Sex (MeFileTag with parent_trait_id = 1)

Age is automatically recalculated and updated on user's birthday each year.

## Testing Considerations

1. Test regular user flow (Steps 1-4)
2. Test proxy user flow (modal → Steps 3-4)
3. Test alias uniqueness validation
4. Test age calculation and range assignment
5. Test zip code validation (STANDARD only)
6. Test under-18 rejection
7. Test incomplete MeFile redirect to registration
8. Test route protection on all protected routes
9. Test OBAN worker with various dates
10. Test transaction rollback on errors

## Future Enhancements

- Real authentication provider integration (Step 1)
- Email/SMS verification
- Profile photo upload
- Additional optional fields
- Admin ability to edit immutable fields with audit log

