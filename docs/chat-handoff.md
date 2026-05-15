# Chat Handoff: Myth OS Local RP Stack

This document captures the working context from the setup chat so another project or agent can continue without reconstructing the whole thread.

## Current Repo State

- Local root: `G:\MythOS`
- Remote: `git@github.com:CodyBriscoe/myth-os.git`
- Branch: `master`
- Recent commits:
  - `3b748a4 Fix orchestrator launch path`
  - `e0b9f68 Document future multiplayer mode`
  - `319eddc Harden RP stack first-run flow`
  - `9e440b3 Initialize local RP stack`

The repo was renamed from `G:\WorldBuilding` to `G:\MythOS`. Scripts are designed to resolve paths relative to the repo root, so the rename should not break normal use.

## Project Intent

Build a local, tinkering-friendly RP environment that can become a semi-autonomous world simulation:

- SillyTavern-first RP frontend.
- KoboldCpp local inference backend on Windows/AMD.
- TheDrummer RP model lane for emotional, human-feeling prose.
- Durable continuity through a local Python + SQLite memory service.
- Reusable cards, prompts, lorebooks, author notes, and sampler presets.
- Future expansion into multiplayer and multimodal/image generation.

V1 is about getting playable local RP working. Image generation is explicitly not required in V1.

## Current Installed Runtime Pieces

- SillyTavern checkout: `apps\SillyTavern`
- SillyTavern dependencies: installed with `npm install`
- KoboldCpp executable: `apps\KoboldCpp\koboldcpp.exe`
- Model: `models\llm\Cydonia-24B-v3e-Q4_K_M.gguf`
- Partial model file was deleted after stale PowerShell download processes were stopped.
- Orchestrator service: `orchestrator\server.py`
- Orchestrator DB default: `data\rp_memory.sqlite`

The model file was present at about 13.35 GiB when checked by `scripts\doctor.ps1`.

## First Commands To Run

PowerShell may block scripts unless `-ExecutionPolicy Bypass` is used.

From repo root:

```powershell
git config --global --add safe.directory G:/MythOS
git config --global --add safe.directory G:/MythOS/apps/SillyTavern
powershell -ExecutionPolicy Bypass -File .\scripts\doctor.ps1
```

If doctor passes, use three terminals for easiest debugging:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-orchestrator.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-koboldcpp.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-sillytavern.ps1
```

Expected service URLs:

- KoboldCpp: `http://127.0.0.1:5001`
- SillyTavern: usually `http://127.0.0.1:8000`
- Orchestrator health: `http://127.0.0.1:8001/health`

## Key Scripts

- `scripts\doctor.ps1`: readiness gate. Checks directories, Git/Node/Python, usable `.gguf`, KoboldCpp exe, SillyTavern launch method, orchestrator presence, and ports.
- `scripts\start-orchestrator.ps1`: starts Python memory server. Fixed to use repo-relative full path, so it works even when launched from `scripts\`.
- `scripts\start-koboldcpp.ps1`: starts KoboldCpp with the detected GGUF and `--usevulkan` unless disabled.
- `scripts\start-sillytavern.ps1`: starts SillyTavern, preferring `node server.js` when `node_modules` exists.
- `scripts\launch.ps1`: one-shot background launch with readiness polling.
- `scripts\models.ps1`: TheDrummer model download helper with manual fallback.
- `scripts\install-apps.ps1`: SillyTavern/KoboldCpp install/update helper.

## RP Assets

General templates:

- `rp_assets\sillytavern\system_prompt.md`
- `rp_assets\sillytavern\gm_narrator_card_template.json`
- `rp_assets\sillytavern\character_card_template.json`
- `rp_assets\sillytavern\lorebook_world_info_starter.json`
- `rp_assets\sillytavern\author_notes.md`
- `rp_assets\sillytavern\summary_memory_prompts.md`

Starter Campaign v1:

- `rp_assets\sillytavern\starter_campaign_v1_gm_card.json`
- `rp_assets\sillytavern\starter_campaign_v1_lorebook_world_info.json`
- `rp_assets\sillytavern\starter_campaign_v1_mara_voss_card.json`

Sampler/model config:

- `config\sillytavern_thedrummer_sampler_preset.json`
- `config\sillytavern_thedrummer_sampler_variants.json`
- `config\thedrummer_model_notes.md`

For fastest first play, import the Starter Campaign v1 GM card and lorebook, paste the system prompt, use the Starter Campaign author note, then connect SillyTavern to KoboldCpp.

## Orchestrator Memory Service

The orchestrator is a stdlib Python HTTP service backed by SQLite.

Endpoints:

- `GET /health`
- `POST /events`
- `POST /summaries`
- `GET /memory/search?q=...`
- `GET /state/world`
- `POST /scene/visual-cue`

V1 bridge is manual-first: after a scene/session, use SillyTavern to generate a summary and POST it into the orchestrator. See `docs\memory-bridge.md`.

## Important Gotchas Already Hit

- PowerShell execution policy blocks `.\script.ps1` by default. Use `powershell -ExecutionPolicy Bypass -File ...`.
- Git safe-directory warnings happen because earlier setup used different Windows users/sandbox identity. Add safe directories for `G:/MythOS` and `G:/MythOS/apps/SillyTavern`.
- `start-orchestrator.ps1` originally failed from the `scripts` directory because it looked for `scripts\server.py`; fixed in commit `3b748a4`.
- A stale `.gguf.partial` was locked by old PowerShell download processes; those were stopped and the partial was deleted.
- If renaming/moving repo is blocked, close PowerShell windows and Codex sessions with the repo as current workspace.

## Future Multiplayer Direction

Small-group multiplayer is feasible:

- 4 players: strong target.
- 8 players: possible with queued/host-controlled GM turns and slower tabletop cadence.
- Best access path: LAN or Tailscale/ZeroTier.
- Recommended architecture: a separate Myth OS multiplayer web app, not forcing SillyTavern into shared multiplayer.
- Humans play PCs; local model acts as GM/NPC/world.
- Use KoboldCpp for generation and SQLite for sessions/messages/summaries.

See `docs\future-multiplayer.md`.

## Good Next Work

1. Run `scripts\doctor.ps1` after the rename and confirm all checks pass.
2. Start orchestrator, KoboldCpp, and SillyTavern in separate terminals.
3. Connect SillyTavern to `http://127.0.0.1:5001`.
4. Import Starter Campaign v1 assets and do first playable smoke session.
5. Capture any launch/UI friction into scripts/docs.
6. Later: design `myth-os multiplayer` as a small local web app with WebSocket/SSE, SQLite sessions, and KoboldCpp prompt calls.

