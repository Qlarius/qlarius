#!/bin/bash

# Check if connection string is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <postgres_connection_string>"
  exit 1
fi

DIR=$(dirname $(realpath "$0"))
SCHEMA_PATH="$DIR/legacy_structure.sql"

REMOTE_CONN="$1"
# local:
TARGET_DB="qlarius_dev"
# prod:
# TARGET_DB=$(gigalixir config | jq -r '.DATABASE_URL')

TABLES=$(ag "CREATE TABLE" $SCHEMA_PATH | cut -d'.' -f2 | cut -d' ' -f1 | sed 's/^/--table=/' | tr '\n' ' ')

pg_dump --data-only $TABLES $REMOTE_CONN > dump.sql
psql -f dump.sql $TARGET_DB
rm dump.sql
