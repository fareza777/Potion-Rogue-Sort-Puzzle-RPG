# Planning Handoff

```text
/make-plan Redesign Potion Rogue's campaign shell and primary game flow. Current design failed audit at 13/30 with critical gaps in principles #3 aesthetic, #4 understandable, #5 unobtrusive, #6 honest, #8 thorough, #9 environmentally friendly, and #10 as little design as possible.

Verdict paragraph:
> The game has a compelling and reusable combat core, but at 13/30 its campaign architecture, information hierarchy, copy honesty, accessibility, and visual-token discipline require a systematic redesign rather than another isolated reskin.

Why redesign and not refine: the total is below 20 and load-bearing clarity/honesty are each 1/3, while a single-run architecture prevents the product loop from extending cleanly.

Preserve from current design:
- Potion sorting as the combat input connected to enemy intents, mana, combos, and rewards (`src/ui/battle_screen.gd:113-227,393-427`).
- Dark fantasy alchemy brand: Cinzel typography, gold/obsidian framing, illustrated enemies, and offline operation (`src/ui/ui_kit.gd:7-18,68-81`; `src/autoload/game_state.gd:56-71`).

Discard:
- One implicit area with fixed Fire Golem termination (`src/run/run_generator.gd:20-35`; `src/autoload/run_state.gd:313-324`). Caused failure on principles #2 and #7.
- Duplicated navigation, uncontrolled literal styling, and misleading labels (`src/ui/main_menu.gd:51-85`; primary UI scripts; `data/events.json:4-7`). Caused failures on principles #3, #4, #5, #6, and #10.

Top moves:
1. #2 Useful — build a data-driven multi-area campaign so boss victory unlocks meaningful next content instead of ending the product loop. Evidence: `src/autoload/run_state.gd:313-324`; `src/run/run_generator.gd:20-35`.
2. #6 Honest — make every label and event cost map 1:1 to behavior, including Continue, Map, Hall saving, objectives, kits, and crystals. Evidence: `src/ui/main_menu.gd:60-85`; `data/events.json:4-7`; `src/ui/battle_screen.gd:113-227`.
3. #3 Aesthetic — consolidate the visual system from 127 literal colors and 22 font sizes into semantic area palettes and a controlled type/spacing scale. Evidence: `src/ui/ui_kit.gd:7-18`; primary UI scripts.
4. #8 Thorough — close broken/missing interaction states, especially active-run restoration, armor-goal progress, focus navigation, accessible potion identity, and user-facing error/result feedback. Evidence: `src/autoload/run_state.gd:101-134`; `src/battle/objective_controller.gd:59-61`.
5. #9 Environment — add measurable Android budgets and cache recurring work, including audio stems, idle redraw, texture dimensions, memory, package size, and scene startup. Evidence: `src/autoload/audio_manager.gd:218-301`; `src/ui/dungeon_route.gd:37-45`.

Redesign principles in priority order:
1. Useful (#2) — each completed run opens a clear next authored goal while remaining replayable.
2. Understandable and honest (#4/#6) — every label, cost, progress number, and completion message matches state and behavior.
3. Thorough and restrained (#8/#10) — all states are covered with fewer duplicated controls and quieter ornament.

Deliverables:
- Data-driven three-area campaign architecture and selection flow.
- Versioned save migration and active-run restoration.
- Area-specific backgrounds, audio, palettes, enemy pools, and bosses.
- Truthful victory/unlock and event/economy copy.
- Controlled visual tokens and accessibility state checklist.
- Android performance budgets and release validation.

Anti-patterns:
- Porting the single-area structure under different background images.
- Adding more hard-coded area branches or boss ID checks.
- Hiding event costs or silently creating runs from Continue/Map.
- Treating the Preserve list as optional.
```
