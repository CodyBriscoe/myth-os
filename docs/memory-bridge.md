# Memory Bridge V1

The V1 memory bridge is manual-first by design. SillyTavern stays unmodified; the local
orchestrator stores durable scene facts, summaries, relationship beats, and future image
cues.

## Flow

1. Play in SillyTavern.
2. Every scene or session, use `rp_assets\sillytavern\summary_memory_prompts.md`.
3. Store the result in the orchestrator with PowerShell examples below.
4. Before next play, search memory and paste key facts into Author's Note, lorebook, or a recap message.

## Store Event

```powershell
$body = @{
  type = "scene"
  actor = "Narrator"
  scene_id = "session-001"
  content = "Mara promised to guide the user through the flood tunnels, but hid that she knows the locked door code."
  tags = @("promise", "secret", "mara")
} | ConvertTo-Json

Invoke-RestMethod -Uri http://127.0.0.1:8001/events -Method Post -ContentType "application/json" -Body $body
```

## Store Summary

```powershell
$body = @{
  scope = "relationship:mara"
  title = "Mara trust state"
  summary = "Mara is protective but evasive. She trusts the user enough to help, not enough to reveal her old employer."
} | ConvertTo-Json

Invoke-RestMethod -Uri http://127.0.0.1:8001/summaries -Method Post -ContentType "application/json" -Body $body
```

## Search Before Play

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8001/memory/search?q=mara"
```

## Store Future Image Cue

This does not generate images in V1. It records visual state for later ComfyUI work.

```powershell
$body = @{
  scene_id = "session-001"
  cue = "flood tunnel shrine, brass moon lock, knee-deep black water"
  prompt = "A flooded underground rail shrine with a brass moon lock, moody practical light"
  style = "cinematic realistic"
} | ConvertTo-Json

Invoke-RestMethod -Uri http://127.0.0.1:8001/scene/visual-cue -Method Post -ContentType "application/json" -Body $body
```

## STscript Later

Later automation can call these same endpoints from SillyTavern script buttons or extension hooks. Keep V1 manual until endpoint shape and desired summary format feel good in play.
