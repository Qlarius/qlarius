# Maintenance Scripts

This directory contains SQL scripts and utilities for database maintenance tasks that may need to be run in production or during migrations.

## Scripts

### `remove_duplicate_target_populations.sql`

**Purpose:** Removes duplicate target population records while preserving the oldest entry for each unique (target_band_id, me_file_id) combination.

**When to use:**
- Before adding unique constraints to the target_populations table
- When duplicate populations have been created
- During production database cleanup

**Usage:**
```bash
# Local development
psql -d qlarius_dev < priv/maintenance_scripts/remove_duplicate_target_populations.sql

# Production (via Fly.io console or similar)
fly postgres connect -a <app-name>
\i priv/maintenance_scripts/remove_duplicate_target_populations.sql
```

**Related Migration:** `20251105013343_add_unique_index_to_target_populations.exs`

## Best Practices

1. **Always backup** before running maintenance scripts in production
2. **Test locally** or in staging environment first
3. **Run in a transaction** (BEGIN/COMMIT) so you can ROLLBACK if needed
4. **Monitor execution time** for large tables
5. **Check results** before committing the transaction

## Adding New Scripts

When adding new maintenance scripts:
1. Use descriptive filenames
2. Include comprehensive comments explaining purpose and usage
3. Add entry to this README
4. Include backup recommendations
5. Show before/after verification queries

