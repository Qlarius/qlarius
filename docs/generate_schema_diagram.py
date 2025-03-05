#!/usr/bin/env python3
import os
import re
import subprocess
from pathlib import Path
from collections import defaultdict

# Configuration
SCHEMA_DIR = "lib/qlarius"
OUTPUT_FILE = "docs/data_model.mmd"
PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__) + "/..")

# Define patterns to extract information
SCHEMA_PATTERN = re.compile(r'schema\s+"([^"]+)"')
FIELD_PATTERN = re.compile(r'\s+field\s+:(\w+),\s+([^,\n]+)')
BELONGS_TO_PATTERN = re.compile(r'belongs_to\s+:(\w+),\s+([^,\n]+)')
HAS_MANY_PATTERN = re.compile(r'has_many\s+:(\w+),\s+([^,\n]+)')
HAS_ONE_PATTERN = re.compile(r'has_one\s+:(\w+),\s+([^,\n]+)')
MANY_TO_MANY_PATTERN = re.compile(r'many_to_many\s+:(\w+),\s+([^,\n]+)')
MODULE_PATTERN = re.compile(r'defmodule\s+([^\s]+)\s+do')

class Schema:
    def __init__(self, name, module, table_name):
        self.name = name  # Schema name (e.g., User)
        self.module = module  # Full module name
        self.table_name = table_name  # Table name (e.g., users)
        self.fields = []
        self.associations = []

def snake_to_pascal(snake_case):
    """Convert snake_case to PascalCase"""
    return ''.join(word.title() for word in snake_case.split('_'))

def find_schema_files():
    """Find all files containing 'use Ecto.Schema'"""
    os.chdir(PROJECT_ROOT)
    result = subprocess.run(
        ["grep", "-l", "use Ecto.Schema", "-r", SCHEMA_DIR, "--include=*.ex"],
        capture_output=True,
        text=True
    )
    return result.stdout.strip().split('\n')

def extract_schema_info(file_path):
    """Extract schema information from a file"""
    schemas = []
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Extract module name
    module_match = MODULE_PATTERN.search(content)
    if not module_match:
        return []
    
    module_name = module_match.group(1)
    
    # Extract schema name
    schema_match = SCHEMA_PATTERN.search(content)
    if not schema_match:
        return []
    
    table_name = schema_match.group(1)
    # Get the module's last part as the schema name (in PascalCase)
    schema_name = module_name.split('.')[-1]
    
    schema = Schema(schema_name, module_name, table_name)
    
    # Extract fields
    for field_match in FIELD_PATTERN.finditer(content):
        field_name = field_match.group(1)
        field_type = field_match.group(2).strip()
        schema.fields.append((field_name, field_type))
    
    # Extract associations
    for pattern, assoc_type in [
        (BELONGS_TO_PATTERN, "belongs_to"),
        (HAS_MANY_PATTERN, "has_many"),
        (HAS_ONE_PATTERN, "has_one"),
        (MANY_TO_MANY_PATTERN, "many_to_many")
    ]:
        for match in pattern.finditer(content):
            assoc_name = match.group(1)
            assoc_module = match.group(2).strip()
            schema.associations.append((assoc_type, assoc_name, assoc_module))
    
    schemas.append(schema)
    return schemas

def get_target_schema_name(assoc_name, schema_map):
    """Try to determine the correct target schema name"""
    # Handle special cases
    if assoc_name == "entries":
        return "LedgerEntry"
        
    # Try to find the schema by its name directly
    for schema_name in schema_map.keys():
        if schema_name.lower() == assoc_name.lower():
            return schema_name
    
    # For plural association names, try the singular form
    if assoc_name.endswith('s'):
        singular = assoc_name[:-1]
        for schema_name in schema_map.keys():
            if schema_name.lower() == singular.lower():
                return schema_name
                
    # Convert from snake_case to PascalCase
    pascal_case = snake_to_pascal(assoc_name)
    if pascal_case.endswith('s'):
        pascal_case = pascal_case[:-1]
        
    for schema_name in schema_map.keys():
        if schema_name == pascal_case:
            return schema_name
            
    # Last resort: return the PascalCase version
    return pascal_case

def format_field_type(field_type):
    """Format the field type for the Mermaid diagram"""
    # Remove Elixir-specific notation
    field_type = field_type.replace("{:array, ", "array_of_")
    field_type = field_type.replace("}", "")
    field_type = field_type.replace(":", "")
    return field_type.strip()

def generate_mermaid_diagram(schemas):
    """Generate a Mermaid ERD diagram"""
    mermaid = [
        "---",
        "title: Qlarius Data Model",
        "---",
        "erDiagram"
    ]
    
    # Create a map of schema names for lookup
    schema_map = {schema.name: schema for schema in schemas}
    
    # Process relations
    relations = set()
    for schema in schemas:
        for assoc_type, assoc_name, assoc_module in schema.associations:
            target_schema_name = get_target_schema_name(assoc_name, schema_map)
            
            # Skip if we can't determine the target schema
            if not target_schema_name:
                continue
            
            # Format the relation based on association type
            if assoc_type == "belongs_to":
                relation = f"    {schema.name} ||--o| {target_schema_name} : belongs_to"
            elif assoc_type == "has_many":
                relation = f"    {schema.name} ||--o{{ {target_schema_name} : has"
            elif assoc_type == "has_one":
                relation = f"    {schema.name} ||--|| {target_schema_name} : has"
            elif assoc_type == "many_to_many":
                relation = f"    {schema.name} }}|--|{{ {target_schema_name} : has"
            else:
                continue
                
            if relation:
                relations.add(relation)
    
    # Add relations to diagram
    mermaid.extend(sorted(relations))
    
    # Generate entities
    for schema in schemas:
        mermaid.append("")
        mermaid.append(f"    {schema.name} {{")
        
        for field_name, field_type in schema.fields:
            formatted_type = format_field_type(field_type)
            mermaid.append(f"        {formatted_type} {field_name}")
        
        mermaid.append("    }")
    
    return '\n'.join(mermaid)

def main():
    # Find all schema files
    schema_files = find_schema_files()
    all_schemas = []
    
    # Extract schema info from each file
    for file_path in schema_files:
        schemas = extract_schema_info(file_path)
        all_schemas.extend(schemas)
    
    # Generate diagram
    diagram = generate_mermaid_diagram(all_schemas)
    
    # Write to output file
    output_path = os.path.join(PROJECT_ROOT, OUTPUT_FILE)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'w') as f:
        f.write(diagram)
    
    print(f"Mermaid diagram generated at {OUTPUT_FILE}")

if __name__ == "__main__":
    main()