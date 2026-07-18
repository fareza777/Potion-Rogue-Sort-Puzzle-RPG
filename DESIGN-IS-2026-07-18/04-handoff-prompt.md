# Plan Handoff

```text
/make-plan Redesign Potion Rogue's gameplay systems and mobile interface. Current design failed audit at 13/30 with critical gaps in principles #3 aesthetic, #4 understandable, #5 unobtrusive, #6 honest, #8 thorough, #9 environmentally friendly, and #10 as little design as possible.

Verdict paragraph:
> The game should receive a targeted system redesign—not an art reset—because its core gameplay and premium assets are worth preserving, while the 13/30 audit exposes load-bearing clarity, honesty, consistency, and production gaps that isolated polish passes will keep reintroducing.

Why redesign and not refine: multiple structural systems—battle orchestration, procedural pacing, visual tokens, copy semantics, audio lifecycle, accessibility, and release verification—must change together; another isolated reskin would preserve the causes.

Preserve from current design:
- Premium alchemy/fantasy backgrounds, enemy sprites, bottle art, gold/purple identity, and large illustrated hierarchy (`src/ui/visual_registry.gd:8-166`, `src/ui/ui_kit.gd:7-18`).
- Pure BattleManager/controller model, deterministic route topology, encounter snapshot/resume, atomic backup concept, and solver-safe hazard transforms (`src/battle/battle_manager.gd:1-22`, `src/autoload/run_state.gd:140-208`, `src/puzzle/puzzle_board.gd:138-152`).

Discard:
- Ad-hoc palette/type/spacing and duplicated Hall navigation. Evidence: `src/ui/ui_theme_tokens.gd:4-17`, `src/ui/ui_kit.gd:7-18`, `src/ui/main_menu.gd:51-83`. Caused failures on principles #3, #5, and #10.
- Fixed seven-depth macro grammar, fake-adaptive context, and multiplier-only Ascension. Evidence: `src/run/run_generator.gd:4-45,82-100`, `src/run/run_director.gd:9-20`. Caused failures on principles #2 and #4.

Top moves:
1. Principles #2/#8 — Reliable puzzle difficulty: solver-validate every initial board, record estimated minimum moves, and simulate win-rate/damage curves across enemies, areas, and Ascension.
2. Principles #2/#4 — Runtime-aware run structure: generate future route segments from actual HP/build/performance, add area-specific macro grammars, minibosses/secrets, and authored Ascension rules.
3. Principles #3/#5/#10 — One readable visual system: consolidate palettes/tokens/frame families, remove duplicate chrome, raise critical text to mobile-safe sizes, and fix overlap/disabled/selection states.
4. Principles #4/#6 — Truthful feature semantics: align Hero, Offline, Daily, Synergy, reward values, settings persistence, history, and mastery with their real behavior.
5. Principles #8/#9 — Production-grade runtime: split the battle monolith, validate content schemas, harden save commit, repair screen-aware audio, optimize assets/motion, and add Android/perceptual CI gates.

Redesign principles in priority order:
1. Useful — every route and battle decision changes expected risk, reward, or build direction and remains solvable.
2. Understandable/honest — every label states the exact behavior/value and every important state is visible without hover.
3. Aesthetic/restraint — the premium art remains dominant while one token system controls all supporting chrome.

Deliverables:
- New information architecture and battle/map component boundaries.
- New primary run flow compared side-by-side with the current seven-depth flow.
- States checklist: empty, loading, error, success, focus, disabled, resumed, offline, audio interruption, low-memory recovery.
- Save/content migration path for existing users.
- Android cutover gates: balance simulation, screenshot diffs, frame time, memory, startup, audio focus, signing, and APK budget.

Anti-patterns:
- Do not replace the approved art direction with generic flat UI.
- Do not port the existing fixed route under new styling.
- Do not add labels or currencies without exact mechanical meaning.
- Do not keep duplicate old/new systems indefinitely.
```
