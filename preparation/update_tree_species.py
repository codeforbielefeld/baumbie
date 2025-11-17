import os
import sys
import yaml
import json
from supabase import create_client, Client
from utils.env import load_env

# Load environment variables from .env.local (if available), otherwise .env – relative to project root
load_env()

# Get Supabase URL and service role key from environment
url = os.environ.get("VITE_SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    raise ValueError("VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")

# Create Supabase client
supabase: Client = create_client(url, key)

# Ensure a file path was passed as argument
if len(sys.argv) != 2:
    raise ValueError("Usage: python update_tree_species.py <path_to_file.yaml|json>")

path_to_file = sys.argv[1]

# Load data file (YAML or JSON)
with open(path_to_file, encoding="utf-8") as f:
    if path_to_file.endswith((".yaml", ".yml")):
        data = yaml.safe_load(f)
    elif path_to_file.endswith(".json"):
        data = json.load(f)
    else:
        raise ValueError("File must be .yaml, .yml or .json")

# Upsert records into the 'tree_species' table using 'tree_type_botanic' as unique key
for item in data:
    supabase.table("tree_species").upsert(item, on_conflict="tree_type_botanic").execute()
    print(f"{item['tree_type_botanic']} ✔")