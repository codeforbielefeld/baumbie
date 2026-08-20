# Xylem

Xylem ist die Wikidata-Daten-Pipeline für das BaumBie-Projekt. Sie lädt und
verarbeitet Baumarten-Daten, erzeugt eine CSV für das manuelle Review und
importiert die freigegebenen Daten anschließend in Supabase.

```text
Wikidata → generate → verarbeitete RDF-Daten → export → Review-CSV → import → Supabase
```

Alle Befehle in dieser README werden aus diesem Verzeichnis ausgeführt. Details
und zusätzliche Optionen stehen direkt bei den Tasks, zum Beispiel mit
`mix help xylem.generate`.

## Einrichten

```bash
direnv allow
mix deps.get
```

Für einen Supabase-Import muss außerdem die lokale Supabase-Instanz vom
Repository-Root aus gestartet sein und `.envrc` auf diese Instanz zeigen.

## Wikidata-Daten aktualisieren und importieren

Der übliche vollständige Ablauf ist:

```bash
# Wikidata-Daten laden und verarbeiten
mix xylem.generate

# Review-CSV aus den verarbeiteten Daten erzeugen
mix xylem.export

# Import zuerst vollständig prüfen, ohne Supabase zu verändern
mix xylem.import --dry-run

# Die geprüften Daten importieren
mix xylem.import
```

`generate` meldet am Ende, welche Properties es neu in
`priv/config/wikidata_properties.csv` ergänzt hat. Diese Einträge tragen nur
aus dem Wikidata-Datentyp abgeleitete Defaults und müssen geprüft werden. Vor dem Import muss außerdem
`priv/data/wikidata/export.csv` manuell reviewed sein – sie ist versioniert, das
Review ist also der `git diff` gegen den zuletzt importierten Stand. Wenn neu
ergänzte Property-Einträge geändert wurden, `generate` vor dem Export noch einmal
ausführen. Der schreibende Import sollte nur ausgeführt werden, wenn der
Dry-Run erfolgreich war und sicher auf die gewünschte Supabase-Instanz zeigt.

Wenn die verarbeiteten RDF-Daten bereits aktuell sind, genügt der Ablauf ab
`mix xylem.export`. Wenn eine fertige und geprüfte Review-CSV vorliegt, genügt
der Ablauf ab `mix xylem.import --dry-run`.

## Citree-Zuordnungen aktualisieren

Der Citree-Abgleich ist ein separater Datenpflege-Schritt. Änderungen immer
zuerst ohne Schreibzugriff ansehen:

```bash
mix xylem.reconcile_citree --dry-run
mix xylem.reconcile_citree
```

Den schreibenden Lauf erst starten, nachdem Matches und Unmatched-Einträge des
Dry-Runs geprüft wurden.

## Dateien in `priv`

`priv` ist in drei Ebenen aufgeteilt:

| Verzeichnis | Inhalt | Git |
|---|---|---|
| `priv/config` | Stellschrauben: steuern, **wie** die Pipeline arbeitet | versioniert |
| `priv/data` | Datensätze: das, **woran** sie arbeitet, inklusive der reviewten Ergebnisse | versioniert |
| `priv/cache` | Vollständig generiert und jederzeit reproduzierbar | ignoriert |

`priv/cache` darf komplett gelöscht werden; ein erneutes `mix xylem.generate`
stellt den Inhalt wieder her (der Fetch dauert dann allerdings eine Weile).

### `priv/config` – Steuerung der Pipeline

Hier liegt mit `wikidata_properties.csv` die versionierte, zugleich wichtigste
Stellschraube des Projekts: Sie steuert, welche Wikidata-Properties verarbeitet,
aufgelöst und importiert werden. Die Datei ist semikolon-separiert mit den
Spalten `property_id;type;action;config;description;import`. Neue Zeilen hängt
`mix xylem.generate` automatisch an, sobald es unbekannte Properties in den
Daten findet; die Entscheidungsspalten werden **manuell** gepflegt:

- `property_id`, `type`, `description` – von `generate` aus Wikidata befüllt,
  normalerweise nicht von Hand anzufassen
- `action` – steuert die **Verarbeitung**: leer (behalten), `ignore`
  (entfernen) oder `inline` (verlinktes Entity durch sein Label ersetzen)
- `config` – JSON zur `inline`-Action (`target`, optional `source`,
  `keep_source`)
- `import` – steuert den **Supabase-Import**: leer (importieren), `skip`
  (nicht importieren) oder JSON mit `group`/`attribute_name`

`action` und `import` sind bewusst getrennt: Eine Property kann verarbeitet
werden, ohne in Supabase zu landen. Neu angehängte Zeilen tragen nur aus dem
Wikidata-Datentyp abgeleitete Defaults (ExternalIds werden auf `skip` gesetzt,
WikibaseItems auf `inline`) und sind genau die Einträge, die `generate` am Ende
zum Review meldet.

Daneben liegen in `citree_matching/` die beiden Stellschrauben des
Citree-Abgleichs. Beide sind rein manuell gepflegt, werden von keinem Task
geschrieben und dürfen fehlen:

- `synonyms.csv` – Synonym-Tabelle für Namen, die sich nicht automatisch
  abgleichen lassen
- `manual_wikidata_ids.csv` – direkt gesetzte Wikidata-IDs für Namen, die auch
  mit Synonymen kein Match finden

### `priv/data` – Datensätze

| Pfad | Inhalt | Erzeugt/gepflegt von |
|---|---|---|
| `baumbie_wikidata_mapping.csv` | Referenz-Mapping Baumart → Wikidata-ID (`baumart_bo,baumart_de,wikidata_id`); Ausgangspunkt aller drei Pipeline-Schritte | **Manuell** gepflegt; von keinem Task geschrieben |
| `citree_matching/mapping.csv` | Citree-Baumnamen mit zugeordneter Wikidata-ID und `baumart_bo` | Herkunft Citree-Projekt; `mix xylem.reconcile_citree` schreibt die gefundenen Zuordnungen **an Ort und Stelle** zurück |
| `wikidata/export.csv` | Flache Review-CSV, eine Zeile je Wert (`wikidata_id;baumart_bo;baumart_de;property_id;attribute_name;value;group`) | `mix xylem.export` erzeugt sie, **manuelles Review** korrigiert sie, `mix xylem.import` liest sie |

Dass `export.csv` versioniert ist, macht sie zum eigentlichen Review-Punkt der
Pipeline: Ein erneutes `mix xylem.export` überschreibt sie zwar, aber `git diff`
zeigt dann genau, was sich seit dem letzten Stand in Wikidata geändert hat.
Diesen Diff vor dem Commit durchsehen. Korrekturen, die dauerhaft gelten sollen,
gehören trotzdem in `priv/config/wikidata_properties.csv` oder ins Mapping – von
Hand in der Review-CSV geändertes wird beim nächsten Export wieder überschrieben.

Damit dieser Diff aussagekräftig bleibt, ist die Zeilenreihenfolge des Exports
vollständig determiniert: Arten in der Reihenfolge des Mappings, Properties nach
ID, Werte sortiert.

### `priv/cache` – generierte Zwischenstände

Nicht versioniert (siehe `.gitignore`) und jederzeit über `mix xylem.generate`
reproduzierbar.

| Pfad | Inhalt | Erzeugt von |
|---|---|---|
| `wikidata/raw/<QID>.ttl` | Unveränderte Wikidata-EntityData als Turtle, eine Datei je Entity | Fetch-Schritt (dient zugleich als Cache; `--fetch` steuert das Verhalten) |
| `wikidata/processed/<QID>.ttl` | Gefilterte und aufgelöste Graphen je Entity – nur konfigurierte Properties, Inline-Labels statt Links | Process-Schritt |
| `wikidata/meta/vocab.ttl` | Beschreibungen aller verwendeten Properties (per SPARQL von Wikidata) | Vocab-Schritt |

### Das Baumkataster liegt außerhalb von `priv`

`mix xylem.import` leitet die `tree_types` aus den Baumkataster-Daten der Stadt
Bielefeld ab und liest sie per Default aus `../input/trees2.geojson` – also aus
`preparation/input/`, wo auch die übrigen Preprocessing-Skripte ihre GeoJSON-
Eingaben erwarten. Wer sie woanders liegen hat, gibt den Pfad mit `--trees` an.

## Task-Hilfe

```bash
mix help xylem.generate
mix help xylem.export
mix help xylem.import
mix help xylem.reconcile_citree
```

Damit sind alle projektspezifischen Mix-Tasks abgedeckt:

- `xylem.generate` – Wikidata-Daten laden und verarbeiten
- `xylem.export` – Review-CSV erzeugen
- `xylem.import` – Review-CSV nach Supabase importieren
- `xylem.reconcile_citree` – Citree-Namen mit dem BaumBie-Mapping abgleichen

## Nutzung mit Docker

Ohne Argumente führt das Image die Generate-Pipeline aus:

```bash
docker compose build
docker compose run --rm xylem
```

Der Entrypoint ist `mix`, es lässt sich also jeder Task mit seinen Optionen
wählen:

```bash
docker compose run --rm xylem xylem.generate --limit 10
docker compose run --rm xylem xylem.export
docker compose run --rm xylem help xylem.export
```

`mix xylem.import` läuft bewusst nur lokal: Das Image bekommt weder die
Supabase-Zugangsdaten aus der Umgebung noch das Baumkataster (`trees2.geojson`
liegt außerhalb der gemounteten Verzeichnisse), und `localhost` zeigt im
Container nicht auf eine lokale Supabase-Instanz. Der schreibende Import soll
dort laufen, wo sicher erkennbar ist, auf welche Instanz er zeigt.

## Entwicklung

```bash
mix check   # format --check-formatted, compile --warnings-as-errors, test
```
