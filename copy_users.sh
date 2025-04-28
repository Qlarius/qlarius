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

# Dump the users table from remote DB
pg_dump "$REMOTE_CONN" --table=users --data-only --no-owner --no-privileges --no-comments --no-sync --format=plain > users_dump.sql

# Check if dump was successful
if [ $? -ne 0 ]; then
  echo "Error: Failed to dump users table from remote database"
  rm -f users_dump.sql
  exit 1
fi

# Filter out comments and SET statements, keep COPY command and data
grep -v '^--\|^SET' users_dump.sql > users_data.sql

# Inspect the filtered file for debugging (optional, comment out if not needed)
echo "Filtered data file contents:"
head -n 10 users_data.sql

# Check if filtered file is empty
if [ ! -s users_data.sql ]; then
  echo "Error: No data found in filtered dump"
  rm -f users_dump.sql users_data.sql
  exit 1
fi

# Run the filtered SQL file directly to execute the COPY command
psql -d "$LOCAL_DB" -f users_data.sql

# Check if import was successful
if [ $? -ne 0 ]; then
  echo "Error: Failed to import users table into local database"
  rm -f users_dump.sql users_data.sql
  exit 1
fi

# Clean up
rm -f users_dump.sql users_data.sql
echo "Successfully copied users table to $LOCAL_DB"
