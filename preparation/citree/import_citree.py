import json
import os

from dotenv import load_dotenv
from supabase import create_client

load_dotenv("../../.env")

SUPABASE_URL = os.environ["VITE_SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

print(SUPABASE_URL)
print(SUPABASE_KEY)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

with open("tree-information.json", "r") as f:
    data = json.load(f)

TREE_META_KEYS = {"id", "name_trivial", "name_botanic", "strain", "images"}


def value_type(value):
    """Determine the type string for a JSON value."""
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, list):
        return "string"
    if isinstance(value, (int, float)):
        return "number"
    return "string"


def value_to_string(value):
    """Convert a JSON value to its string representation for storage."""
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        return ", ".join(str(v) for v in value)
    return str(value)

def s3_file_exists(supabase, bucket_name, file_path):
    """Check if a file exists in the Supabase storage bucket."""
    response = supabase.storage.from_(bucket_name).list(path=os.path.dirname(file_path))
    if len(response) == 0:
        return False
    for file_info in response:
        if file_info["name"] == os.path.basename(file_path):
            return True
    return False

# 1. Create the "citree" provider

provider_result = (
    supabase.table("providers")
    .upsert({"name": "citree"}, on_conflict="name")
    .execute()
)
provider_uuid = provider_result.data[0]["uuid"]
print(f"Provider: {provider_uuid}")

# 2. Build attribute group and attribute lookups from the JSON schema

attribute_to_group = {}
attribute_descriptions = {}
for group_name, attributes in data["attributes"].items():
    for attr_name, description in attributes.items():
        attribute_to_group[attr_name] = group_name
        attribute_descriptions[attr_name] = description

# Determine the type for each attribute by inspecting the first non-null value across all trees
attribute_types = {}
for attr_name in attribute_to_group:
    for tree in data["trees"]:
        val = tree.get(attr_name)
        if val is not None:
            attribute_types[attr_name] = value_type(val)
            break
    else:
        attribute_types[attr_name] = "string"

# 3. Insert attribute groups

group_names = list(data["attributes"].keys())
group_rows = [{"name": name} for name in group_names]
group_result = supabase.table("tree_type_attribute_groups").upsert(
    group_rows, on_conflict="name"
).execute()
group_uuid_map = {row["name"]: row["uuid"] for row in group_result.data}
print(f"Attribute groups: {len(group_uuid_map)}")

# 4. Insert attributes

attribute_rows = [
    {
        "name": attr_name,
        "description": attribute_descriptions[attr_name] or None,
        "type": attribute_types[attr_name],
        "provider_uuid": provider_uuid,
        "tree_type_attribute_group_uuid": group_uuid_map[attribute_to_group[attr_name]],
    }
    for attr_name in attribute_to_group
] + [
    {
        "name": "CiTree-Bild",
        "description": None,
        "type": "string",
        "provider_uuid": provider_uuid,
        "tree_type_attribute_group_uuid": None,  # No group for images
    }
]
attr_result = supabase.table("tree_type_attributes").upsert(
    attribute_rows, on_conflict="provider_uuid,name"
).execute()
attr_uuid_map = {row["name"]: row["uuid"] for row in attr_result.data}
print(f"Attributes: {len(attr_uuid_map)}")

# 5. Insert tree types

tree_type_rows = [
    {
        "name": tree["name_trivial"],
        "name_trivial": tree["name_trivial"],
        "name_botanic": tree["name_botanic"],
        "strain": tree.get("strain"),
        "citree_id": str(tree["id"]),
    }
    for tree in data["trees"]
]
tree_result = supabase.table("tree_types").upsert(
    tree_type_rows, on_conflict="citree_id"
).execute()
tree_uuid_map = {row["citree_id"]: row["uuid"] for row in tree_result.data}
print(f"Tree types: {len(tree_uuid_map)}")

# 6. Insert attribute values
# Delete existing values for these tree types to support re-runs
for tree_type_uuid in tree_uuid_map.values():
    supabase.table("tree_type_attribute_values").delete().eq(
        "tree_type_uuid", tree_type_uuid
    ).execute()
print("Cleared existing attribute values for imported tree types")

BATCH_SIZE = 500
value_rows = []
for tree in data["trees"]:
    tree_type_uuid = tree_uuid_map[str(tree["id"])]
    for attr_name, attr_uuid in attr_uuid_map.items():
        val = tree.get(attr_name)
        if val is None:
            continue
        
        # separate information with multiple values into multiple rows, one for each value
        if isinstance(val, list):
            for item in val:
                value_rows.append({
                    "tree_type_uuid": tree_type_uuid,
                    "tree_type_attribute_uuid": attr_uuid,
                    "type": value_type(item),
                    "value": value_to_string(item),
                })
            continue

        value_rows.append({
            "tree_type_uuid": tree_type_uuid,
            "tree_type_attribute_uuid": attr_uuid,
            "type": value_type(val),
            "value": value_to_string(val),
        })

image_rows = []
for tree in data["trees"]:
    for image_url in tree.get("images", []):
        print(f"Processing image {image_url} for tree {tree['id']}")
        s3_image_url = f"{tree['id']}/{image_url}"
        if not s3_file_exists(supabase, "tree_type_images", s3_image_url):
            image_rows.append({
                "tree_type_uuid": tree_type_uuid,
                "filename": f"images/{image_url}",
            })
            upload_response = supabase.storage.from_("tree_type_images").upload(s3_image_url, open(f"../citree-scraper/images/{image_url}", "rb"), {
                "content-type": "image/jpeg",
            })
            print(json.loads(upload_response.content.decode("utf-8"))['Key'])
            print(f"Uploaded image {image_url} to Supabase storage: {upload_response}")
        else:
            print(f"Image {image_url} already exists in Supabase storage, skipping upload.")
        
        value_rows.append({
            "tree_type_uuid": tree_type_uuid,
            "tree_type_attribute_uuid": attr_uuid_map["CiTree-Bild"],
            "type": "string",
            "value": supabase.storage.from_("tree_type_images").get_public_url(s3_image_url),
        })

# Insert in batches
for i in range(0, len(value_rows), BATCH_SIZE):
    batch = value_rows[i : i + BATCH_SIZE]
    try:
        supabase.table("tree_type_attribute_values").insert(batch).execute()
    except Exception as e:
        print(f"Error inserting batch {i // BATCH_SIZE + 1}: {e}")
        print(batch)
    print(f"Inserted attribute values batch {i // BATCH_SIZE + 1} ({len(batch)} rows)")

print(f"Total attribute values: {len(value_rows)}")
print("Done.")