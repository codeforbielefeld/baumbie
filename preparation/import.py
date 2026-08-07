import os
import json
import sys
from tqdm import tqdm
from supabase import create_client, Client
import pyproj
from utils.env import load_env

# Lädt Umgebungsvariablen aus .env.local (wenn vorhanden) oder .env
load_env()

url: str = os.environ.get("VITE_SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    raise ValueError("VITE_SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY müssen in .env/.env.local gesetzt sein")

supabase: Client = create_client(url, key)

if len(sys.argv) == 2:
    path_to_geojson = sys.argv[1]
else:
    raise ValueError("""
    No path to the geojson file was provided. Please provide the file path as an argument when starting the script:
    python3 import.py /tmp/my-super-geo-json-file.json
    """)

projection = pyproj.Proj(proj='utm', zone=32, ellps='WGS84')
def unproject(x, y):
    return projection(x, y, inverse=True)


def create_insert_data(feature, provider_id):
    return {
        "provider_id": provider_id,
        "source_id": feature["properties"]["pitID"],
        "location": feature["properties"]["Standort_N"],
        "location_addition": feature["properties"]["Zusatz"],
        "current_number": feature["properties"]["laufende_N"],
        "chopped": 1 if feature["properties"]["gefaellt"] == "WAHR" else 0,
        "trunk_diameter": feature["properties"]["Stammdurch"],
        "trunk_circumference": feature["properties"]["Stammumfan"],
        "crown_diameter": feature["properties"]["Kronendurc"],
        "height": feature["properties"]["Baumhoehe_"],
        "tree_group": feature["properties"]["Baumgruppe"] or "",
        "district_number": feature["properties"]["Bezirk_Nr"],
        "district_name": feature["properties"]["Bezirk_Bez"] if "Bezirk_Bez" in feature["properties"] else None,
        "object_number": feature["properties"]["Objekt_Nr"],
        "object_name": feature["properties"]["Objekt_Bez"],
        "tree_type_botanic": feature["properties"]["Baumart_bo"],
        "tree_type_german": feature["properties"]["Baumart_de"],
        "tree_type_short": feature["properties"]["Baumart_ku"],
        "care_number": feature["properties"]["PflE_Art_N"],
        "care_type": feature["properties"]["PflE_Art_B"],
        "trunk_radius": feature["properties"]["Stammdurch"] / 2 if feature["properties"]["Stammdurch"] is not None else None,
        "crown_radius": feature["properties"]["Kronendurc"] / 2 if feature["properties"]["Kronendurc"] is not None else None,
        "geocoordinates": "POINT(" + str(feature["geometry"]["coordinates"][0]) + " " + str(feature["geometry"]["coordinates"][1]) + ")",
        "object_number_1": feature["properties"]["Standort_N"],
        "planting_year": feature["properties"]["Pflanzjahr"] or 0,
    }


with open(path_to_geojson) as f:
    data = json.load(f)

    city = supabase.table("providers").insert({
        "name": "Stadt Bielefeld",
    }).execute()
    city_uuid = city.data[0]["uuid"]

    rows = [create_insert_data(feature, city_uuid) for feature in data["features"]]
    rows = [row for row in rows if row is not None]
    for row in tqdm(rows):
        supabase.table("trees").insert(row).execute()