#!/bin/bash

# Check if connection string is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <postgres_connection_string>"
  exit 1
fi

REMOTE_CONN="$1"
LOCAL_DB="qlarius_dev"

# Extract database name by splitting on '/' and taking the last field
DB_NAME=$(echo "$REMOTE_CONN" | cut -d '/' -f 4 | cut -d '?' -f 1)

# Check if DB_NAME was extracted
if [ -z "$DB_NAME" ]; then
  echo "Error: Could not extract database name from connection string"
  exit 1
fi

tables=("me_files" "ledger_headers" "ledger_entries")

for table in "${tables[@]}"; do
  # Dump the table from remote DB
  pg_dump "$REMOTE_CONN" --table="$table" --data-only --no-owner --no-privileges --no-comments --no-sync --format=plain > "${table}_dump.sql"

  # Check if dump was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to dump $table table from remote database"
    rm -f "${table}_dump.sql"
    exit 1
  fi

  # Filter out comments and SET statements, keep COPY command and data
  grep -v '^--\|^SET' "${table}_dump.sql" > "${table}_data.sql"

  # Inspect the filtered file for debugging (optional, comment out if not needed)
  echo "Filtered data file contents for $table:"
  head -n 10 "${table}_data.sql"

  # Check if filtered file is empty
  if [ ! -s "${table}_data.sql" ]; then
    echo "Error: No data found in filtered dump for $table"
    rm -f "${table}_dump.sql" "${table}_data.sql"
    exit 1
  fi

  # Run the filtered SQL file directly to execute the COPY command
  psql -d "$LOCAL_DB" -f "${table}_data.sql"

  # Check if import was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to import $table table into local database"
    rm -f "${table}_dump.sql" "${table}_data.sql"
    exit 1
  fi

  # Clean up
  rm -f "${table}_dump.sql" "${table}_data.sql"
  echo "Successfully copied $table table to $LOCAL_DB"
done
