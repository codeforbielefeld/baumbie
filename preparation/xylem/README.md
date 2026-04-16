# Xylem

Daten-Pipeline für das BaumBie-Projekt. Lädt Baumarten-Daten von Wikidata basierend auf einer CSV-Datei mit Wikidata-IDs.

**Input:** `priv/data/citree_wikidata_mapping.csv` (CSV mit Wikidata-IDs)
**Output:** `priv/data/wikidata/raw/*.ttl` (RDF-Daten im Turtle-Format)


## Nutzung mit Docker

### Image bauen

```bash
docker compose build
```

### Pipeline ausführen

```bash
# Alle Spezies verarbeiten
docker compose run --rm xylem

# Anzahl limitieren
docker compose run --rm xylem --limit 10
```

### Optionen

- `--csv PATH` - Pfad zur Input-CSV-Datei (default: `priv/data/citree_wikidata_mapping.csv`)
- `--raw PATH` - Verzeichnis für die Output-TTL-Dateien (default: `priv/data/wikidata/raw`)
- `--limit N` - Nur N Spezies verarbeiten


## Lokale Entwicklung (mit Elixir)

```bash
# Dependencies installieren
mix deps.get

# Tests
mix test

# Pipeline ausführen
mix xylem.generate
```
