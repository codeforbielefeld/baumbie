# 🌳 BaumBie

BaumBie bringt Menschen mit der Natur in Verbindung. Die interaktive Karte zeigt Bäume an und bringt sie zum Sprechen. Für jeden Baum zeigt die App grundlegende Informationen an, etwa Alter, Baumart oder Höhe. Außerdem ist der Wasserbedarf und die Regenmenge der letzten Zeit zu sehen. Vor allem können Nutzer:innen sich spielerisch in einem Chat mit dem Baum auseinandersetzen und ihm Fragen stellen. Eine weitere wichtige Funktion der App: Die Bäume können adoptiert werden. So erfahren Nutzer:innen live, wie es ihrem Baum geht und können beim Gießen des Baums helfen. Ein Baum kann mehrere Pat:innen haben. Das soll auch Nachbarschaften zusammenbringen.

Grundlage der Karte ist aktuell das Baumkataster der Stadt Bielefeld, es sind also alle Stadtbäume zu sehen. Das Projekt ist so angelegt, dass auch Privatpersonen, oder andere Organisationen Daten mit uns teilen können, damit wir ihre Bäume in der App zeigen können.

Das Projekt ist inspiriert von "Gieß den Kiez" aus Berlin. Es wird entwickelt von Ehrenamtlichen aus dem Verein Code for Bielefeld e.V. Wir sind ein gemeinnütziger Verein für digitale Bildung, Open Source, Open Data und Civic Coding. Wir setzen unsere technischen und kreativen Fähigkeiten ein, um unsere Stadt zu verbessern und sind Teil der bundesweiten Initiative "Code for Germany" von der Open Knowledge Foundation. Wir freuen uns über weitere Interessierte.

## 🧱 Tech Stack

Unsere Anwendung basiert auf einem kompakten Fullstack-Setup:

- **Frontend: Svelte**

  Svelte ist ein komponentenbasiertes JavaScript-Framework, ähnlich wie React oder Vue.js. Im Gegensatz zu diesen nutzt Svelte kein virtuelles DOM, sondern kompiliert Komponenten bereits beim Build in effizienten, direkt ausführbaren JavaScript-Code. Das führt zu geringeren Ladezeiten und erleichtert die Umsetzung interaktiver Benutzeroberflächen - bei uns vollständig in TypeScript umgesetzt.

- **Backend: Supabase**

  Supabase ist ein Open-Source-Backend-as-a-Service auf Basis von PostgreSQL. Wir können damit Authentifizierung, Datenbankzugriff, Datei-Uploads und öffentliche APIs direkt aus der Datenbank heraus konfigurieren – ohne zusätzlichen Server-Code, was die Komplexität senkt.

- **Conversational AI: Voiceflow**

  Voiceflow ist eine Plattform zur Erstellung von Chatbots und Sprachassistenten über ein grafisches No-Code-Interface. Sie erlaubt es uns, die Chatdialoge mit einzelnen Bäumen visuell zu modellieren, ohne selbst Code schreiben zu müssen. Die Kommunikation mit Voiceflow erfolgt über einen per Edge Function angebundenen API-Endpunkt in Supabase.

  > 🚨 Da die Preisstruktur von Voiceflow derzeit unklar ist und die Plattform nicht selbst gehostet werden kann, evaluieren wir mittelfristig Alternativen – z.B. durch eigene LLM-Backends.

## 🔐 Umgebungsvariablen

Die Anwendung benötigt eine `.env`-Datei im Projekt-Root, die dem Muster von [`.env.example`](./.env.example) folgt. Sie enthält die Zugangsdaten für Supabase und Voiceflow.

### 🗄️ Supabase

| Variable                    | Beschreibung                                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `VITE_SUPABASE_URL`         | Supabase-Projekt-URL (Cloud-Instanz oder lokal), z. B. `https://xyzabc12.supabase.co` oder `http://localhost:54321` |
| `VITE_SUPABASE_ANON_KEY`    | Öffentlicher Schlüssel für clientseitige Authentifizierung und Lesezugriff auf die Datenbank                        |
| `SUPABASE_SERVICE_ROLE_KEY` | Geheimer Server-Schlüssel mit Schreibrechten (⚠️ **Nicht im Frontend verwenden** ⚠️)                                    |

`VITE_SUPABASE_URL` wird gemeinsam mit dem öffentlichen `VITE_SUPABASE_ANON_KEY` in der zentralen [client.ts](./frontend/src/lib/supabase/client.ts) verwendet, um den Supabase-Client im Frontend zu initialisieren.

Der private `SUPABASE_SERVICE_ROLE_KEY` kommt vor allem in den Python-Skripten im Verzeichnis [`/preparation`](/preparation) zum Einsatz – etwa beim Importieren von Baumdaten oder dem Anlegen von Tabellen. Darüber hinaus wird er in Supabase Edge Functions genutzt, z.B. zum Löschen von Nutzerkonten über die Admin-API.

> 🚨 Für die Entwicklung empfiehlt es sich, zusätzlich eine `.env.local` anzulegen, die auf die lokale Supabase-Instanz verweist. Falls vorhanden, überschreibt sie standardmäßig die `.env`.

### 💬 Voiceflow

| Variable            | Beschreibung                                                                                                                |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `VOICEFLOW_API_KEY` | API-Schlüssel für die Voiceflow-Integration (nur in der Supabase Edge Function [`chat`](/supabase/functions/chat/index.ts)) |

## 🛠️ Lokales Dev-Setup

### 🐳 Supabase-Instanz starten

Für die lokale Entwicklung muss eine Supabase-Instanz aufgesetzt werden. Dafür verwenden wir die [`supabase-cli`](https://supabase.com/docs/guides/cli).

Installiere sie zum Beispiel mit `npm` (du kannst alternativ auch andere Paketmanager nutzen):

```bash
npm install -g supabase-cli
```

Die Supabase CLI verwendet intern **Docker**, um Dienste wie PostgreSQL, Auth und Studio lokal bereitzustellen. Docker ist eine Container-Laufzeitumgebung: Die Supabase CLI startet mehrere Container (für Datenbank, Auth etc.) und kapselt sie voneinander ab – ähnlich wie Mini-VMs, aber schneller und leichtgewichtiger.

Stelle also sicher, dass die Docker Engine auf deinem System installiert und aktiv ist:

- **macOS/Windows**: Installiere [Docker Desktop](https://www.docker.com/products/docker-desktop/), starte es und lasse es im Hintergrund laufen. Der kostenlose Personal-Plan ist ausreichend.
- **Linux**: Folge der [offiziellen Anleitung zur Docker-Installation](https://docs.docker.com/engine/install/) für deine Distribution.

Wenn Supabase CLI und Docker eingerichtet sind, kannst du deine lokale Instanz im **Projekt-Root** starten:

```bash
supabase start
```

Sobald die Instanz läuft, kannst du das Supabase Studio – die grafische Oberfläche zur Verwaltung deiner lokalen Datenbank – im Browser unter http://127.0.0.1:54323/ aufrufen.

> 🚨 Beim ersten Start führt die Supabase CLI automatisch alle `.sql`-Migrations aus dem Ordner [supabase/migrations/](/supabase/migrations/) aus. Dadurch wird die im Projekt definierte Datenbankstruktur aufgebaut – also alle Tabellen, Views, Policies und weitere SQL-Objekte, die in den Migrationen enthalten sind. Die Tabellen bleiben aber zunächst leer, da in unserem Projekt kein Seed-Skript definiert ist.

### 🎛️ Umgebungsvariablen setzen

Kopiere die Datei `.env.example` und benenne sie um in `.env.local`:

```bash
cp .env.example .env.local
```

Sobald du `supabase start` ausgeführt hast, zeigt dir das Terminal eine Liste mit Konfigurationswerten an – darunter die URL deiner lokalen Instanz sowie die API-Schlüssel.

> 🚨 Die API URL bleibt immer http://127.0.0.1:54321 (bzw. http://localhost:54321). Kopiere dir den `anon key` und den `service_role key` aus dem Terminal-Output und notiere sie für die Konfiguration!

Trage die folgenden drei Werte (ohne Anführungszeichen!) in deine `.env.local`-Datei ein:

```ini
VITE_SUPABASE_URL=http://localhost:54321
VITE_SUPABASE_ANON_KEY=<anon key>
SUPABASE_SERVICE_ROLE_KEY=<service_role key>
```

### ⬆️ Migrationen answenden

Wenn du neue Tabellen oder Änderungen an deiner Datenbankstruktur vornimmst, solltest du dafür Migrationen erstellen. Supabase speichert sie als `.sql`-Dateien im Ordner [supabase/migrations/](/supabase/migrations/).

Beim ersten Start mit `supabase start` werden alle Migrationen automatisch angewendet.

Spätere Änderungen (z. B. neue Tabellen, Spalten oder Policies) erfordern jedoch einen manuellen Schritt:

```bash
supabase migrations up
```

Dieser Befehl führt **alle noch nicht angewendeten Migrationen** aus und aktualisiert deine lokale Datenbankstruktur entsprechend.

### 🌱 Baumdaten importieren & segmentieren

Nachdem die Supabase-Instanz läuft und alle Tabellen eingerichtet wurden, können die Baumdaten importiert und für die performante Kartendarstellung vorbereitet werden.

#### 🐍 Virtuelle Python-Umgebung vorbereiten

Wechsle zunächst ins `preparation`-Verzeichnis und erstelle eine virtuelle Python-Umgebung:

```bash
cd preparation
python3 -m venv .venv
source .venv/bin/activate
```

Die virtuelle Umgebung stellt sicher, dass alle benötigten Python-Pakete sauber und unabhängig vom restlichen System installiert werden können.

Installiere anschließend alle benötigten Abhängigkeiten:

```bash
python -m pip install -r requirements.txt
```

#### 📥 Baumdaten importieren

Lege deine GeoJSON-Datei am besten im Verzeichnis `preparation/input/` ab. Führe dann das Importskript aus und gib dabei den Pfad zu deiner Datei an, z.B.:

```bash
./.venv/bin/python import.py input/trees.geojson
```

Das Skript verwendet automatisch die Umgebungsvariablen aus `.env.local` (falls vorhanden) oder `.env`, um sich mit Supabase zu verbinden.

> 🚨 Nach diesem Schritt solltest du im Supabase Studio (http://127.0.0.1:54323/) sehen können, dass insbesondere die `trees`-Tabelle mit Baumdaten befüllt wurde.

#### 🌍 Geo-Splitting der Baumdaten

Da es in Bielefeld über 80.000 Stadtbäume gibt, wäre es technisch ineffizient, alle Baumdaten gleichzeitig in der Karte zu laden. Das würde zu langen Ladezeiten und hohem Speicherverbrauch führen – vor allem auf mobilen Geräten.

Stattdessen teilen wir die Koordinaten der importierten Bäume nach dem Upload in kleinere GeoJSON-Dateien auf, sogenannte Segmente. Jede dieser Dateien enthält nur die Bäume eines bestimmten geografischen Ausschnitts.

Das Frontend lädt dann ausschließlich die Segmente, die zum aktuell sichtbaren Kartenausschnitt gehören. Erst wenn ein einzelner Baum im Detail angezeigt wird, wird dessen vollständiger Datensatz direkt aus Supabase abgerufen. Das ermöglicht flüssiges Rendering – selbst bei zehntausenden Bäumen – und spart dabei Ladezeit und Ressourcen.

Führe dazu im `preparation/`-Ordner das folgende Skript aus:

```bash
python supa_splitter.py
```

Das Skript lädt die Koordinaten direkt aus der Supabase-Tabelle `tree_coordinates`, teilt sie in ein 10×10-Raster und erstellt pro Rasterzelle eine Datei unter `preparation/segments/`.

Zusätzlich wird eine Datei `segments_index.json` erzeugt, die die Übersicht über alle _Bounding Boxes_ enthält – also die rechteckigen geografischen Begrenzungen der einzelnen Segmente. Damit kann das Frontend gezielt nur jene Dateien laden, deren Bereich gerade auf der Karte sichtbar ist.

Kopiere oder verschiebe anschließend die neu erstellten Segmente aus `preparation/segments/` nach `frontend/static/segments`. Dazu kannst du den `segments/`-Ordner entweder manuell verschieben oder folgenden Befehl ausführen:

```bash
cp -r preparation/segments frontend/static/segments
```

### ▶️ App starten

Wechsle in den `frontend/`-Ordner und installiere alle benötigten Abhängigkeiten:

```bash
cd frontend
npm install
```

Anschließend kannst du das mit Svelte entwickelte Frontend im Entwicklungsmodus starten:

```
npm run dev
```

> 🚨 Das Projekt läuft nun standardmäßig unter http://localhost:5173. Du solltest jetzt eine Karte mit Bäumen sehen.

### 🧹 Lokale Supabase zurücksetzen

Mit folgenden Befehl kannst du die lokale Instanz wieder beenden:

```bash
supabase stop
```

Dieser Befehl beendet nur die laufenden Container, setzt aber nicht den Datenbankinhalt zurück. Supabase speichert alle Daten in einem Docker Volume, das unabhängig vom Container-Lifecycle bestehen bleibt.

Wenn du alle Daten dauerhaft löschen und die lokale Instanz vollständig zurücksetzen möchtest, kannst du die zugehörigen Volumes manuell entfernen:

1. Liste die lokalen Supabase-Volumes auf:

   ```bash
   docker volume ls
   ```

   Du solltest Volumes sehen, die dem Schema entsprechen:

   ```
   supabase_db_<Projektverzeichnis> \
   supabase_storage_<Projektverzeichnis> \
   supabase_config_<Projektverzeichnis> \
   supabase_edge_runtime_<Projektverzeichnis>
   ```

2. Entferne alle zugehörigen Volumes:

   ```
   docker volume rm \
   supabase_db_<Projektverzeichnis> \
   supabase_storage_<Projektverzeichnis> \
   supabase_config_<Projektverzeichnis> \
   supabase_edge_runtime_<Projektverzeichnis>
   ```

   Dadurch wird die komplette lokale Supabase-Instanz gelöscht, inklusive Datenbank, Authentifizierung, Dateien und Konfiguration. Der Vorgang ist nicht umkehrbar.

## 🌐 Produktivbetrieb

Um BaumBie produktiv zu betreiben, verwendest du eine gehostete Supabase-Instanz in der Cloud.

### 🧾 Supabase-Projekt in der Cloud erstellen

Melde dich auf [https://app.supabase.com](https://app.supabase.com) an und erstelle ein neues Projekt. Folge den Anweisungen und wähle als Region einen Ort, der möglichst nah an deinen Nutzern liegt (z. B. Frankfurt für Deutschland).

### 🔑 Zugangsdaten abrufen

Nach der Erstellung deines Projekts erhältst du alle notwendigen Zugangsdaten im Supabase Studio:

1. Öffne dein Projekt in [https://app.supabase.com](https://app.supabase.com)
2. Klicke unten links auf **Project Settings**
3. Wähle im Bereich **Configuration** den Punkt **Data API**
4. Dort findest du:
   - `Project URL` → verwende diesen Wert als `VITE_SUPABASE_URL`
5. Klicke in diesem Bereich auf **"Go to API Keys"**, um zu den API-Schlüsseln zu gelangen:

   - `anon public` → verwende als `VITE_SUPABASE_ANON_KEY`
   - `service_role secret` → verwende als `SUPABASE_SERVICE_ROLE_KEY` **(nicht im Frontend verwenden!)**

   Lege eine `.env`-Datei im Projekt-Root an (z. B. durch Kopieren von `.env.example`) und trage die Werte ein:

```ini
VITE_SUPABASE_URL=<Project URL>
VITE_SUPABASE_ANON_KEY=<anon public>
SUPABASE_SERVICE_ROLE_KEY=<service_role secret>
```

### 🛠️ Supabase CLI installieren & verbinden

Installiere die Supabase CLI (falls noch nicht geschehen):

```bash
npm install -g supabase-cli
```

Melde dich bei Supabase über die CLI an:

```bash
supabase login
```

Anschließend verknüpfst du dein Projekt mit deiner Cloud-Instanz per Project ID, die du in oben deinen Project Settings findest oder aus der Project URL extrahieren kannst:

```bash
supabase link --project-ref <dein-project-ref>
```

### ⬆️ Migrationen anwenden

Sobald dein Projekt verknüpft ist, kannst du alle vorhandenen Migrationen auf deine Cloud-Datenbank anwenden:

```bash
supabase db push
```

Dadurch werden alle Migrationsdateien angewendet, die lokal vorhanden, aber in der Supabase-Cloud noch nicht ausgeführt wurden – also etwa Tabellen, Views, Policies und andere SQL-Objekte.

### 🌱 Baumdaten importieren & segmentieren

Sobald deine Supabase-Cloud-Instanz eingerichtet und mit Migrationen befüllt ist, kannst du wie im lokalen Setup die Baumdaten importieren und segmentieren.

Folge dafür dem beschriebenen Ablauf im Abschnitt **🌱 Baumdaten importieren & segmentieren** weiter oben.

Die dort beschriebenen Schritte zur Python-Umgebung, dem Import der GeoJSON-Datei sowie zur Segmentierung und Kopie ins Frontend bleiben unverändert – wichtig ist lediglich, dass deine `.env`-Datei auf die Supabase-**Cloud-Instanz** zeigt.

### 🛰️ Frontend bauen & deployen

Erzeuge ein Produktions-Build deiner Svelte-App:

```bash
cd frontend
npm install
npm run build
```

Das erzeugte statische Frontend liegt unter `frontend/build/`. Du kannst es über beliebige Hoster (z. B. Zugriff.eu, Vercel, Netlify oder eigenes Hosting) ausliefern.
