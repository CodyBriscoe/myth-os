# RP Memory Orchestrator

Small local HTTP service for RP continuity memory. Uses Python stdlib only:
`http.server`, `sqlite3`, and `json`.

## Run

```powershell
python orchestrator\server.py
```

Defaults:

- Host: `127.0.0.1`
- Port: `8001`
- DB: `data\rp_memory.sqlite`

Override with flags or env:

```powershell
python orchestrator\server.py --host 127.0.0.1 --port 8001 --db data\rp_memory.sqlite
```

```powershell
$env:RP_MEMORY_DB="data\rp_memory.sqlite"
$env:RP_MEMORY_PORT="8001"
python orchestrator\server.py
```

## SillyTavern Bridge: Manual V1

V1 bridge is intentionally manual. After a scene, ask SillyTavern to summarize with
`rp_assets\sillytavern\summary_memory_prompts.md`, then store the result here.
This avoids brittle edits to SillyTavern internals while still giving durable memory.

Store a scene event:

```powershell
$body = @{
  type = "scene"
  actor = "Narrator"
  scene_id = "session-001"
  content = "The party found the sealed moon gate beneath the old rail station."
  tags = @("discovery", "moon-gate")
} | ConvertTo-Json

Invoke-RestMethod -Uri http://127.0.0.1:8001/events -Method Post -ContentType "application/json" -Body $body
```

Store a summary:

```powershell
$body = @{
  scope = "world"
  title = "Session 001"
  summary = "The moon gate exists, is sealed, and reacts to old station brass."
} | ConvertTo-Json

Invoke-RestMethod -Uri http://127.0.0.1:8001/summaries -Method Post -ContentType "application/json" -Body $body
```

Recall memory:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/memory/search?q=moon-gate"
```

Before the next session, paste useful recalled memory into Author's Note, lorebook, or chat summary.

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
