# WorldBuilding RP Stack

Local SillyTavern-first RP environment for Windows + AMD GPU.

V1 goal: get from empty workspace to playable local RP with:

- SillyTavern frontend
- KoboldCpp Vulkan backend
- TheDrummer 24B-32B GGUF model drop zone and download helper
- RP starter assets: prompts, narrator card, character template, lorebook, author notes
- Python + SQLite continuity service

Image generation is not required for V1. ComfyUI hooks are only placeholders for later.

## Quick Start

1. Run `scripts\check-prereqs.ps1`.
2. Run `scripts\setup-workspace.ps1`.
3. If model download fails, place a `.gguf` model in `models\llm\`.
4. If app install fails, put `koboldcpp.exe` in `apps\KoboldCpp\` and clone SillyTavern into `apps\SillyTavern\`.
5. Start services:
   - `scripts\start-orchestrator.ps1`
   - `scripts\start-koboldcpp.ps1 -ModelPath models\llm\YOUR_MODEL.gguf`
   - `scripts\start-sillytavern.ps1`
6. Open SillyTavern, connect to KoboldCpp, import/use assets from `rp_assets\`.

For one-shot background launch after apps/model exist, run `scripts\launch.ps1`.

See `docs\rp-first-run.md` for exact flow.
