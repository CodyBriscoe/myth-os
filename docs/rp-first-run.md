# RP Starter Kit First Run

This kit gives SillyTavern a play-ready baseline for TheDrummer-style roleplay. It includes system guidance, narrator and character card templates, lorebook starter entries, author notes, memory prompts, sampler settings, and model notes.

## Files

- `rp_assets/sillytavern/system_prompt.md`: paste into system prompt or equivalent instruct field.
- `rp_assets/sillytavern/gm_narrator_card_template.json`: import as a narrator or GM character card.
- `rp_assets/sillytavern/character_card_template.json`: copy, rename, fill, then import for specific characters.
- `rp_assets/sillytavern/lorebook_world_info_starter.json`: import as SillyTavern world info/lorebook and replace bracketed text.
- `rp_assets/sillytavern/author_notes.md`: paste one matching note into Author's Note.
- `rp_assets/sillytavern/summary_memory_prompts.md`: use for summaries, memory, and handoffs.
- `config/sillytavern_thedrummer_sampler_preset.json`: import or copy values into sampler settings.
- `config/thedrummer_model_notes.md`: quick tuning notes.

## Quick Start

1. Import `gm_narrator_card_template.json` into SillyTavern.
2. Paste `system_prompt.md` into the system prompt field for the chat or preset.
3. Import `lorebook_world_info_starter.json` as World Info.
4. Replace bracketed lorebook text with campaign facts.
5. Paste one author note from `author_notes.md`.
6. Apply sampler values from `sillytavern_thedrummer_sampler_preset.json`.
7. Start chat with a character concept, opening location, and desired tone.

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
