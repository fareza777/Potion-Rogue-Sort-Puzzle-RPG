# Consolidated Evidence

## 1. Innovative

- The product combines solver-verified potion sorting, seeded route topology, hidden route disclosure, enemy intents/signatures, boss phases, and adaptive music (`src/puzzle/board_factory.gd:42-73`, `src/run/run_generator.gd:10-65`, `src/ui/dungeon_route.gd:208-214`, `src/ui/battle_screen.gd:178-224`).
- The interaction remains recognizable as a color-sort roguelike rather than a wholly new genre.

## 2. Useful

- Main menu has nine rendered actions, but Upgrades and Settings are duplicated between its command stack and bottom navigation (`src/ui/main_menu.gd:51-83`).
- Battle exposes eleven baseline controls: six tubes, two powers, and Undo/New Mix/Pause (`src/puzzle/puzzle_board.gd:43-53`, `src/ui/battle_screen.gd:549-616`).
- New Mix truthfully spends one move (`src/ui/battle_screen.gd:608-611,1098-1105`).

## 3. Aesthetic

- Declared spacing tokens are 4/8/16/24/36 and type tokens are 12/16/18/22/32/52, yet screens use many additional ad-hoc values and observed fonts span 9–78px (`src/ui/ui_theme_tokens.gd:4-20`; `src/ui/battle_screen.gd:405-635`).
- Static scan found 180 unique literal hex colors / 208 references across UI, battle, and puzzle code, while semantic tokens cover only a small subset (`src/ui/ui_theme_tokens.gd:10-17`, `src/ui/ui_kit.gd:7-18`).
- Frost and Abyss area cards fall back to Shadow Crypt gold rather than distinct realm accents (`src/ui/area_select_screen.gd:110-114`).

## 4. Understandable

- Route cards distinguish revealed/mystery/fog states and battle exposes objective, intent, enemy trick, mana, and action costs (`src/ui/dungeon_route.gd:118-175,208-214`, `src/ui/battle_screen.gd:539-616`).
- Several labels do not describe behavior: Hero opens Credits; Offline is hardcoded; Daily +15 remains after claim; Ascension does not disclose its rules (`src/ui/main_menu.gd:78,86-98`, `src/ui/area_select_screen.gd:32-38,126-156`).
- Build Summary details are tooltip-only, which is not discoverable by touch (`src/ui/build_summary.gd:38-46`).

## 5. Unobtrusive

- Menu duplicates destinations, and menu particles plus route glow redraw continuously while idle (`src/ui/main_menu.gd:51-83`, `src/ui/ambient_particles.gd:29-47`, `src/ui/dungeon_route.gd:37-45`).
- Supplied and deterministic captures show ornate frames sometimes competing with small tactical text.

## 6. Honest

- Build labels Synergy/Mastery are derived from item counts rather than actual compatibility; exact reward values exist but user-facing descriptions remain vague (`src/ui/build_summary.gd:38-54`, `data/relics.json:2-15`, `data/mutations.json:2-15`).
- Daily says “same challenge for everyone” but is only based on local date/hash, without UTC/server verification (`src/ui/area_select_screen.gd:38`, `src/run/meta_progression.gd:7-8`).
- A configured corruption intent sends unsupported `append_corruption` and ignores failure, so the promised action may silently do nothing (`src/battle/enemy_intent_controller.gd:72-78`, `src/puzzle/puzzle_board.gd:155-218`).

## 7. Long-lasting

- Save migrations, run boundaries, solver-safe generation, and data-driven content provide a durable foundation (`src/autoload/save_system.gd:89-181`, `src/autoload/run_state.gd:172-208`).
- `battle_screen.gd` has 1,122 lines and owns construction, battle wiring, save snapshots, tutorials, VFX dispatch, rewards, pause, and navigation, increasing future change cost (`src/ui/battle_screen.gd:1-1122`).

## 8. Thorough

- Victory, defeat, pause, confirmation, disabled, locked, save-recovery, exact-resume, reduced-effects, and 576×1280 regression states exist.
- Missing or incomplete states include loading, recoverable error, app-wide focus order, screen-reader semantics, text-size/high-contrast controls, and fully honored reduced motion.
- Skill/Ultimate, settings switches, sliders, and map Back controls fall below the declared 56px touch contract (`src/ui/ui_theme_tokens.gd:4`, `src/ui/battle_screen.gd:563-566`, `src/ui/settings_screen.gd:102-108,153-160`).

## 9. Environmentally friendly

- APK v14 is 73,153,501 bytes (69.76 MiB); four unreferenced legacy atlases total 5,563,250 bytes while export includes all resources (`export_presets.cfg:9-12`).
- Audio startup eagerly evaluates synthesized fallbacks and first combat use synthesizes two eight-second stems (`src/autoload/audio_manager.gd:192-251,306-368`).
- Battle FX allocates transient nodes, resource bars regenerate textures per instance, and idle systems redraw continuously (`src/ui/battle_fx.gd:50-206`, `src/ui/ornate_resource_bar.gd:150-194`).
- Every puzzle move schedules a main-thread full atomic JSON checkpoint (`src/ui/battle_screen.gd:109-159`, `src/autoload/save_system.gd:146-181`).

## 10. As little design as possible

- Four repeated-purpose patterns were found, including duplicate menu destinations and three parallel reward-choice cards.
- Area selector uses fixed crest/action widths and allows horizontal scrolling, producing clipped Enter/Locked actions at 576px (`src/ui/area_select_screen.gd:42-47,55-106`).
- Frost map normalizes every floor by fixed `6.0`, placing higher-realm nodes over the header (`src/ui/dungeon_route.gd:198-201`).

## Engine and feature inventory

- Current breadth: 5 areas, 42 enemies, 5 bosses, 3 kits, 6 events, 11 combos, 5 objectives, 18 relics, 24 mutations, and 12 catalysts.
- Procedural generation always supplies `hp_ratio: 1.0`, so the director’s low-HP recovery branch cannot react to actual run state (`src/run/run_generator.gd:43`, `src/run/run_director.gd:11-15`).
- Upgrade/relic rolls use global shuffling rather than serialized run-owned RNG, so identical seeds do not fully reproduce reward sequences (`src/autoload/run_state.gd:355-374`).
- `complete_mastery()` has no production caller; Daily and Ascension lack authored long-term rule identities (`src/run/meta_progression.gd:26-34`).
- No CI workflow or device frame-time/save-latency/audio-first-use budget was found.

## Known gaps

- No physical-device profiler, TalkBack session, battery/thermal run, or long-session playtest was performed.
- Contrast measurements use flat declared colors and may change after texture/shader compositing.
- APK was not decompressed for exact per-resource packaged attribution.

