# Maintenance Scripts

This directory contains one-off maintenance and data migration scripts for the Qlarius application.

## Available Scripts

### import_zip_metadata.exs

Imports zip code metadata from CSV into the `traits` table.

**Purpose**: Populates the `meta_1`, `meta_2`, and `meta_3` fields for zip code traits with display information from a zip code database. Also creates new trait records for any zip codes in the CSV that don't exist in the database yet.

**Data Source**: `priv/data/zip_code_database_small_business.csv`

**Target Traits**: All traits that are children of:
- Trait ID 4: "Home Zip Code"
- Trait ID 5: "Work Zip Code"

**Metadata Mapping**:
- `meta_1` = "City, State" (e.g., "Austin, TX")
- `meta_2` = Acceptable cities/alternate names (optional, from CSV column E)
- `meta_3` = Type (e.g., "STANDARD", "UNIQUE")

**Usage**:
```bash
# From the project root directory
mix run priv/maintenance_scripts/import_zip_metadata.exs
```

**Expected Output**:
```
========================================
Zip Code Metadata Import Script
========================================

📂 Reading CSV file: /path/to/priv/data/zip_code_database_small_business.csv
⏳ This may take a moment...

✅ Parsed 42,735 zip codes from CSV

🔍 Fetching zip code traits from database...
✅ Found 1,234 zip code traits in database

🔄 Updating existing trait metadata...

  Progress: 1000/1234 traits processed...

🆕 Creating missing zip code traits...

  Found 41,501 zip codes to create

  Progress: 1000/41501 new traits processed...
  Progress: 2000/41501 new traits processed...
  ...

========================================
Import Complete!
========================================

✅ Successfully updated: 1,200 traits
🆕 Successfully created: 41,501 new traits
⚠️  Zip codes not found in CSV: 34 traits
❌ Errors: 0

✨ Done!
```

**Notes**:
- The script will overwrite any existing metadata in the `meta_1`, `meta_2`, and `meta_3` fields
- New traits are created for any zip codes in the CSV that don't exist in the database
- New traits are created as children of "Home Zip Code" (trait_id 4)
- New traits default to: `is_active: true`, `input_type: single_select`, `trait_category_id: 1`
- The script processes all matching traits and creates all missing ones in a single run
- Progress is logged every 1,000 traits for long-running imports

**Safety**:
- Read-only on the CSV file
- Only updates traits with `parent_trait_id` of 4 or 5
- Uses Ecto changesets for safe database updates
- Provides detailed logging of results

**Troubleshooting**:
- If CSV file not found: Ensure `priv/data/zip_code_database_small_business.csv` exists
- If no traits found: Verify that zip code traits have been created with parent_trait_id 4 or 5
- If errors occur: Check the error details in the output for specific trait/data issues

## Running Scripts in Production

To run these scripts on Gigalixir or other production environments:

```bash
# SSH into your Gigalixir console
gigalixir ps:remote_console

# Then run the script
{:ok, _} = :file.set_cwd("/app")
Code.eval_file("priv/maintenance_scripts/import_zip_metadata.exs")
```

Or use the one-liner approach:
```bash
gigalixir run "mix run priv/maintenance_scripts/import_zip_metadata.exs"
```
