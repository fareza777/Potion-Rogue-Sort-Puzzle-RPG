# Evidence

## 1. Innovative

- The core combines a six-bottle water-sort board with RPG damage, healing, shielding, poison, combos, enemy intents/signatures, bosses, route decisions, and build rewards (`src/battle/battle_manager.gd:169-266`, `src/ui/battle_screen.gd:175-215`).
- The combination is distinctive, but the macro run still follows the same five choice floors followed by a fixed boss (`src/run/run_generator.gd:4-45`).

## 2. Useful

- Hall → expedition → kit → route → battle is direct, and exact battle state can resume (`src/autoload/run_state.gd:140-208`).
- The main menu presents nine visible controls while Upgrades and Settings appear twice (`src/ui/main_menu.gd:51-83`).
- Battle exposes eleven base touch targets; route screens usually enable only two or three relevant choices.

## 3. Aesthetic

- Live 576×1280 and 720×1280 captures show strong illustrated fantasy identity, large enemy art, readable primary health bars, and coherent gold/purple branding.
- The implementation has two overlapping token systems and 172 literal hex colors. Declared spacing is 4/8/16/24/36px but many ad-hoc values are used (`src/ui/ui_theme_tokens.gd:4-17`, `src/ui/ui_kit.gd:7-18`).
- Map detail reaches 9px; tactical and build text uses 11–12px. Boss `Armor 44` overlaps the sprite feet in the 720 capture (`src/ui/dungeon_route.gd:119-174`, `src/ui/tactical_readout.gd:10-52`).
- Potion selection halos are flat circles that do not match the ornate art fidelity.

## 4. Understandable

- Tutorial, intent, objective, trick, event effect summaries, and move cost are present (`src/ui/tutorial.gd:38-97`, `src/ui/event_screen.gd:29-45`).
- `Hero` opens Credits, `Offline` is hardcoded, and build `Synergy/Mastery` is derived from item count rather than actual effect interactions (`src/ui/main_menu.gd:75-98`, `src/ui/build_summary.gd:38-54`).
- Critical details are sometimes tooltip-only, which is weak on touch devices (`src/ui/build_summary.gd:43-46`).

## 5. Unobtrusive

- The enemy and puzzle remain the main battle figures, but the battle hierarchy contains at least ten direct information bands plus ornate frames (`src/ui/battle_screen.gd:380-429`).
- The map repeats visually identical hidden cards, then adds header, large frame, status, build summary, and legend; small copy carries the resulting density.

## 6. Honest

- New Mix correctly costs one move, and event choices preview their costs/effects (`src/ui/battle_screen.gd:599-602,1047-1054`, `src/run/event_resolver.gd:14-38`).
- Daily continues to advertise `+15` after the reward is claimed and “same challenge for everyone” is based on local device date without server/UTC verification (`src/ui/area_select_screen.gd:28-37`, `src/run/meta_progression.gd:7-8,63-71`).
- Reduced Effects is persisted in SaveSystem, but battle/menu read ProjectSettings, so restart state can disagree with the toggle (`src/autoload/save_system.gd:20-21`, `src/ui/settings_screen.gd:145-148`, `src/ui/battle_screen.gd:427-428`).

## 7. Long-lasting

- The illustrated alchemy/fantasy language fits the genre rather than a short-lived mobile UI trend.
- Heavy skeuomorphic frames and many bespoke style variants increase maintenance and make some screens feel less unified over time.

## 8. Thorough

- Empty, error, success, failure, focus, disabled, tutorial, pause, abandon, and recovery states exist in parts of the product.
- No reusable loading/retry state was found. Focus is component-dependent, several controls are under the declared 56px touch target, and visual tests do not use screenshot pixel diffs (`src/ui/settings_screen.gd:34-58`, `tests/visual_test.gd:98-303`).
- The initial puzzle generator shuffles but does not call the available solver; only hazard transforms are solver-validated (`src/puzzle/puzzle_board.gd:138-152,221-253`, `src/puzzle/board_solver.gd:6-30`).

## 9. Environmentally friendly

- Reduced Effects gates shake and particle density. Audio caches are bounded (`src/ui/battle_fx.gd:16-153`, `src/autoload/audio_manager.gd:6-24`).
- APK is 64.20 MiB; source assets are 56.8 MiB, including 9.42 MiB WAV. Four unused atlases total about 5.30 MiB and export uses all resources (`export_presets.cfg:3-12`).
- Five continuous visual systems are active, route glow redraws at 25Hz, and there is no Android frame-time, memory, thermal, startup, or smoke-test gate.

## 10. As little design as possible

- Duplicate Hall navigation, tooltip-only build detail, repeated hidden route cards, and dense tactical labels add cognitive load without adding decisions.
- The design can be simplified without discarding the premium brand or illustrated assets.

## Engine and content facts

- 47 source scripts (~6,653 LOC), 25 test suites (~1,812 test LOC), five autoloads.
- Content: three areas, 27 enemies, six events, five objectives, eight modifiers, 15 upgrades, 18 relics, three kits, three bosses, 11 combos, 12 catalysts, and 24 mutations.
- `battle_screen.gd` is 1,071 lines/67 functions and coordinates UI, flow, persistence, audio, animation, rewards, tutorial, and combat controllers.
- The director receives `hp_ratio: 1.0`, making its low-HP recovery branch unreachable in normal generation (`src/run/run_generator.gd:27-35`, `src/run/run_director.gd:9-20`).
- Ascension is primarily +4% enemy scale per level, slightly more elites, and an extra modifier from level three (`src/run/threat_budget.gd:5-16`, `src/run/run_generator.gd:82-100`).
- The run topology is well tested across thousands of seeds, but tests do not simulate survival, moves-to-win, board completion, win rate, or reward efficacy (`tests/run_generation_test.gd:6-76`, `tests/seed_simulation_test.gd:27-35`).
