# RP Starter Kit First Run

This kit gives SillyTavern a play-ready baseline for TheDrummer-style roleplay. It includes system guidance, narrator and character card templates, lorebook starter entries, author notes, memory prompts, sampler settings, and model notes.

## Files

- `rp_assets/sillytavern/system_prompt.md`: paste into system prompt or equivalent instruct field.
- `rp_assets/sillytavern/gm_narrator_card_template.json`: import as a narrator or GM character card.
- `rp_assets/sillytavern/character_card_template.json`: copy, rename, fill, then import for specific characters.
- `rp_assets/sillytavern/lorebook_world_info_starter.json`: import as SillyTavern world info/lorebook and replace bracketed text.
- `rp_assets/sillytavern/starter_campaign_v1_lorebook_world_info.json`: ready-to-play Ashwake Crossing lorebook.
- `rp_assets/sillytavern/starter_campaign_v1_gm_card.json`: ready-to-play Ashwake Crossing GM card.
- `rp_assets/sillytavern/starter_campaign_v1_mara_voss_card.json`: focused NPC card for Mara Voss.
- `rp_assets/sillytavern/author_notes.md`: paste one matching note into Author's Note.
- `rp_assets/sillytavern/summary_memory_prompts.md`: use for summaries, memory, and handoffs.
- `config/sillytavern_thedrummer_sampler_preset.json`: import or copy values into sampler settings.
- `config/sillytavern_thedrummer_sampler_variants.json`: Balanced, Cinematic, and Tight sampler variants.
- `config/thedrummer_model_notes.md`: quick tuning notes.

## Quick Start: Template Path

1. Import `gm_narrator_card_template.json` into SillyTavern.
2. Paste `system_prompt.md` into the system prompt field for the chat or preset.
3. Import `lorebook_world_info_starter.json` as World Info.
4. Replace bracketed lorebook text with campaign facts.
5. Paste one author note from `author_notes.md`.
6. Apply sampler values from `sillytavern_thedrummer_sampler_preset.json`.
7. Start chat with a character concept, opening location, and desired tone.

## Quick Start: Starter Campaign v1

1. Import `starter_campaign_v1_gm_card.json`.
2. Import `starter_campaign_v1_lorebook_world_info.json` as World Info and enable it.
3. Paste `system_prompt.md` into the system prompt field.
4. Paste "Starter Campaign v1 Note" from `author_notes.md` into Author's Note.
5. Apply `sillytavern_thedrummer_sampler_preset.json` or choose a variant from `sillytavern_thedrummer_sampler_variants.json`.
6. Start with a character concept, connection to Ashwake Crossing, or one of the GM card alternate greetings.

Optional: import `starter_campaign_v1_mara_voss_card.json` for a focused scene with Mara instead of full GM play.

## First Message Seed

Use this if you want a fast launch:

```text
I want a grounded, consequence-driven RP. My character is [name], a [role] who wants [goal] but is blocked by [problem]. Start in [location]. Tone: [tone]. Boundaries: [limits].
```

## Tuning

- Too long: lower max tokens to 450-550.
- Too florid: lower temperature to 0.75-0.82 and use the default author note.
- Too passive: add stronger NPC motives to character cards and faction lorebook entries.
- Forgetting facts: move facts from old chat into lorebook or rolling summary.
- Acting for user: reinforce "Never speak, decide, emote, or act for `{{user}}`" in system prompt and post-history instructions.
- Mystery too obvious: hide causes longer, but increase physical clues and NPC contradictions.
- Mystery too opaque: add one witness, one document, or one environmental clue each scene.
