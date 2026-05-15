# Future Feature: Small-Group Multiplayer RP

This is feasible as a local-hosted, invite-only mode for 4 players, with 8 players possible at slower tabletop pace.

## Goal

Let the host run the local stack, send friends join instructions, and run a shared RP session where humans play PCs and the local model acts as GM/NPC/world engine.

This does not need public lobbies, matchmaking, accounts, or large-scale server ops.

## Feasibility

- 4 players: good target for V1 multiplayer.
- 8 players: possible if generation is queued and players accept slower turns.
- Main limit: local inference speed and context size, not networking.
- Best hosting path: LAN or private VPN such as Tailscale/ZeroTier.
- Riskier hosting path: public port forwarding or public tunnels without extra auth.

## Recommended Shape

Do not force SillyTavern itself to become the shared multiplayer room. Use SillyTavern for authoring prompts, cards, lorebooks, and sampler ideas.

Build a small Myth OS multiplayer web app:

- Host runs KoboldCpp, orchestrator, and multiplayer server locally.
- Friends open a browser URL.
- Each player enters display name and character name.
- Shared chat log shows player messages and GM responses.
- A host-only or shared `Ask GM` button sends the current state to KoboldCpp.
- AI writes only GM/NPC/world narration, never player PC actions.
- SQLite stores sessions, players, messages, summaries, and safety notes.

## MVP Features

- Local session page.
- Player join page with display name and PC name.
- Shared chat transcript over WebSocket or Server-Sent Events.
- Turn queue or host-controlled `Ask GM`.
- KoboldCpp generation call using the existing RP system prompt and lore.
- Session export to markdown/json.
- Manual memory bridge to existing orchestrator endpoints.

## Prompt/Data Flow

Prompt should include:

- RP system prompt.
- Campaign lorebook or starter campaign facts.
- Player roster with PC names, goals, and boundaries.
- Recent transcript.
- Rolling scene/session summary.
- Explicit rule: the model controls only GM narration, NPCs, world events, and consequences.

The model response should be appended as a GM message and stored in SQLite.

## 4 vs 8 Players

For 4 players:

- Free chat plus host-controlled GM calls is likely enough.
- Keep recent transcript plus summary in context.

For 8 players:

- Add turn queue or phases.
- Limit player message length.
- Summarize more often.
- Use one model request at a time.
- Expect slower “tabletop table” cadence.

## Security

Preferred friend access:

- Tailscale or ZeroTier private network.
- Basic invite instructions: install VPN, join network, open host URL.

Avoid raw public exposure until auth, rate limits, and security settings are reviewed.

If exposing SillyTavern itself remotely, review its listen, whitelist, basic auth, and user-account settings first. For the multiplayer app, keep auth minimal but real: invite code or shared session password.

## Not In MVP

- Public lobby browser.
- Matchmaking.
- Persistent public server.
- Complex permissions.
- Real-time simultaneous AI agents.
- Image generation.

## Open Implementation Choices

- Runtime: Python FastAPI/WebSockets or Node/Express/WebSocket.
- Access: Tailscale-first vs tunnel-first.
- Control: host-only GM generation vs any player can request GM.
- Storage: reuse orchestrator SQLite or separate multiplayer SQLite with sync hooks.

Recommended first implementation: Python server with SQLite and WebSocket/SSE, separate from SillyTavern, using KoboldCpp as the inference backend.

