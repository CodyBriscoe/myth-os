# First Run: Play-Ready Stack

This is the shortest path from empty workspace to first SillyTavern session.

## 1. Check Machine

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-prereqs.ps1
```

Expected:

- Git, Node, and Python found.
- Ports `5001`, `8000`, and `8001` free.
- AMD/Radeon GPU visible if WMI can see it.
- `vulkaninfo` may be missing; this is a warning, not an automatic failure.

## 2. Install Apps And Try Model Download

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-workspace.ps1
```

This attempts:

- Clone/update SillyTavern into `apps\SillyTavern`.
- Download latest KoboldCpp Windows executable into `apps\KoboldCpp`.
- Download default TheDrummer Cydonia 24B Q4 GGUF into `models\llm`.

Model download can fail because of Hugging Face auth, file name changes, bandwidth, or repo access. If it fails, download a TheDrummer 24B-32B Q4/Q5 GGUF manually and put it in:

```text
models\llm\
```

Good v1 lane:

- `TheDrummer/Cydonia-24B-v3-GGUF`
- `Cydonia-24B-v3e-Q4_K_M.gguf` / `Q4_K_M` first for 16GB VRAM
- `Q5_K_M` only if speed/memory are acceptable

## 3. Launch Services

Before launching, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\doctor.ps1
```

If the model is still downloading, doctor should fail only on the missing usable `.gguf`.

Use three terminals for easiest troubleshooting:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start-orchestrator.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start-koboldcpp.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start-sillytavern.ps1
```

Or launch all in background after apps/model exist:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\launch.ps1
```

Service defaults:

- KoboldCpp: `http://127.0.0.1:5001`
- SillyTavern: usually `http://127.0.0.1:8000`
- Orchestrator: `http://127.0.0.1:8001/health`

## 4. Connect SillyTavern

In SillyTavern:

- API/backend: KoboldCpp or compatible local endpoint.
- Server URL: `http://127.0.0.1:5001`.
- Load sampler values from `config\sillytavern_thedrummer_sampler_preset.json`.
- Paste `rp_assets\sillytavern\system_prompt.md` into system/instruct field.
- Import `rp_assets\sillytavern\gm_narrator_card_template.json`.
- Import or copy `rp_assets\sillytavern\character_card_template.json` for your first character.
- Import `rp_assets\sillytavern\lorebook_world_info_starter.json` as World Info.
- Pick one author note from `rp_assets\sillytavern\author_notes.md`.

For fastest play, use Starter Campaign v1 instead:

- Import `rp_assets\sillytavern\starter_campaign_v1_gm_card.json`.
- Import `rp_assets\sillytavern\starter_campaign_v1_lorebook_world_info.json`.
- Optional focused NPC: `rp_assets\sillytavern\starter_campaign_v1_mara_voss_card.json`.
- Paste "Starter Campaign v1 Note" from `author_notes.md`.

## 5. Start Playing

Fast opening prompt:

```text
I want grounded, consequence-driven RP. My character is [name], a [role] who wants [goal] but is blocked by [problem]. Start in [location]. Tone: [tone]. Boundaries: [limits].
```

During play, use `rp_assets\sillytavern\summary_memory_prompts.md` to compress old scenes into summaries. Optional: POST summaries/events to `http://127.0.0.1:8001` for local continuity storage.

See `docs\memory-bridge.md` for copy-paste memory commands.

Image generation is not part of V1. Scene visual cues can be stored for later ComfyUI integration.
