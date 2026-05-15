# RP Memory Orchestrator

Small local HTTP service for RP continuity memory. Uses Python stdlib only:
`http.server`, `sqlite3`, and `json`.

## Run

```powershell
python orchestrator\server.py
```

Defaults:

- Host: `127.0.0.1`
- Port: `8765`
- DB: `data\rp_memory.sqlite`

Override with flags or env:

```powershell
python orchestrator\server.py --host 127.0.0.1 --port 8765 --db data\rp_memory.sqlite
```

```powershell
$env:RP_MEMORY_DB="data\rp_memory.sqlite"
$env:RP_MEMORY_PORT="8765"
python orchestrator\server.py
```

## Endpoints

### `GET /health`

Returns service status and DB path.

### `POST /events`

Stores timeline event.

```json
{
  "type": "scene",
  "actor": "Narrator",
  "scene_id": "intro",
  "content": "Moon gate opens.",
  "tags": ["omen"]
}
```

### `POST /summaries`

Stores summary.

```json
{
  "scope": "world",
  "title": "Opening",
  "summary": "Moon gate now active."
}
```

### `GET /memory/search?q=moon`

Searches events and summaries with SQLite `LIKE`.

Optional `limit` query param, 1 through 100.

### `GET /state/world`

Returns counts, recent summaries, recent events, and recent visual cues.

### `POST /scene/visual-cue`

Stores visual cue for image-generation hooks.

```json
{
  "scene_id": "intro",
  "cue": "silver moon gate",
  "prompt": "A silver moon gate under pine trees",
  "style": "painterly"
}
```

## Smoke Test

```powershell
python orchestrator\smoke_test.py
```

Expected output:

```text
smoke ok
```
