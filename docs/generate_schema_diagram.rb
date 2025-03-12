#!/usr/bin/env ruby
require 'bundler/inline'

# Ensure the 'pg' gem is installed
begin
  gem 'pg'
rescue Gem::LoadError
  puts 'Installing required gems...'
  system('gem install pg')
end

require 'pg'
require 'fileutils'

MERMAID_FILE = 'docs/data_model.mmd'
DB_NAME = 'qlarius_dev'
DB_USER = 'postgres'
DB_PASSWORD = 'postgres'
DB_HOST = 'localhost'
DB_PORT = 5432

def fetch_tables_and_columns(conn)
  tables = {}
  conn.exec(<<~SQL).each do |row|
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
    ORDER BY table_name, ordinal_position;
  SQL
    table = row['table_name']
    tables[table] ||= []
    tables[table] << [row['column_name'], simplify_type(row['data_type'])]
  end
  tables
end

def fetch_foreign_keys(conn)
  relationships = []
  conn.exec(<<~SQL).each do |row|
    SELECT 
      conrelid::regclass AS from_table,
      a.attname AS from_column,
      confrelid::regclass AS to_table,
      af.attname AS to_column
    FROM pg_constraint
    JOIN pg_attribute a ON a.attnum = ANY(pg_constraint.conkey) AND a.attrelid = pg_constraint.conrelid
    JOIN pg_attribute af ON af.attnum = ANY(pg_constraint.confkey) AND af.attrelid = pg_constraint.confrelid
    WHERE pg_constraint.contype = 'f';
  SQL
    relationships << [row['from_table'], row['from_column'], row['to_table'], row['to_column']]
  end
  relationships
end

# Simplify PostgreSQL types for Mermaid
def simplify_type(sql_type)
  case sql_type
  when /character varying|text/ then 'string'
  when /integer|bigint|smallint/ then 'int'
  when /boolean/ then 'bool'
  when /timestamp|date/ then 'datetime'
  when /numeric|double precision|real/ then 'float'
  else 'unknown'
  end
end

begin
  conn = PG.connect(dbname: DB_NAME, user: DB_USER, password: DB_PASSWORD, host: DB_HOST, port: DB_PORT)
  tables = fetch_tables_and_columns(conn)
  relationships = fetch_foreign_keys(conn)
ensure
  conn.close if conn
end

# Generate Mermaid ER Diagram
mermaid = <<~MERMAID
  ---
  title Database Schema
  ---
  erDiagram
MERMAID

# Add tables
tables.each do |table, columns|
  mermaid << "  #{table} {\n"
  columns.each do |col_name, col_type|
    mermaid << "    #{col_type} #{col_name}\n"
  end
  mermaid << "  }\n"
end

# Add relationships
relationships.each do |from_table, from_col, to_table, to_col|
  mermaid << "  #{from_table} }|--|| #{to_table} : \"#{from_col} → #{to_col}\"\n"
end

# Save Mermaid file
File.write(MERMAID_FILE, mermaid)
puts "Saved ER diagram to #{MERMAID_FILE}"
