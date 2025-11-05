-- Remove Duplicate Target Populations
-- 
-- PURPOSE:
-- Removes duplicate records from the target_populations table where the same
-- me_file_id and target_band_id combination appears multiple times. Keeps only
-- the oldest record (lowest id) for each duplicate set.
--
-- WHEN TO USE:
-- - Before adding a unique index on (target_band_id, me_file_id)
-- - When duplicate populations have been created due to race conditions or bugs
-- - Before production deployment if duplicates exist
--
-- HOW TO RUN IN PRODUCTION:
-- 1. Connect to production database:
--    psql -h <host> -U <user> -d <database>
--
-- 2. Check for duplicates first (optional):
--    SELECT target_band_id, me_file_id, COUNT(*) as count
--    FROM target_populations
--    GROUP BY target_band_id, me_file_id
--    HAVING COUNT(*) > 1
--    ORDER BY count DESC;
--
-- 3. Run this script:
--    \i priv/maintenance_scripts/remove_duplicate_target_populations.sql
--
-- BACKUP RECOMMENDATION:
-- Create a backup of duplicate records before deletion:
--    CREATE TABLE target_populations_duplicates_backup AS
--    SELECT tp.* 
--    FROM target_populations tp
--    INNER JOIN (
--      SELECT target_band_id, me_file_id, MIN(id) as keep_id
--      FROM target_populations
--      GROUP BY target_band_id, me_file_id
--      HAVING COUNT(*) > 1
--    ) dupes ON tp.target_band_id = dupes.target_band_id 
--           AND tp.me_file_id = dupes.me_file_id 
--           AND tp.id <> dupes.keep_id;
--
-- THE DELETE SCRIPT:

BEGIN;

-- Show count before deletion
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT (target_band_id, me_file_id)) as unique_combinations,
  COUNT(*) - COUNT(DISTINCT (target_band_id, me_file_id)) as duplicates_to_remove
FROM target_populations;

-- Delete duplicate records (keeps oldest record for each combination)
DELETE FROM target_populations a USING (
  SELECT MIN(id) as id, target_band_id, me_file_id
  FROM target_populations
  GROUP BY target_band_id, me_file_id
  HAVING COUNT(*) > 1
) b
WHERE a.target_band_id = b.target_band_id
AND a.me_file_id = b.me_file_id
AND a.id <> b.id;

-- Show results
SELECT 
  COUNT(*) as total_records_after,
  COUNT(DISTINCT (target_band_id, me_file_id)) as unique_combinations_after
FROM target_populations;

-- Verify no duplicates remain
SELECT target_band_id, me_file_id, COUNT(*) as count
FROM target_populations
GROUP BY target_band_id, me_file_id
HAVING COUNT(*) > 1;

COMMIT;
-- If any duplicates found above, run ROLLBACK instead of COMMIT

-- After successful cleanup, you can create the unique index:
-- CREATE UNIQUE INDEX target_populations_target_band_id_me_file_id_index 
-- ON target_populations (target_band_id, me_file_id);

