```text
/make-plan Redesign Potion Rogue's mobile UI/runtime/progression system. Current design failed audit at 13/30 with critical gaps in principles #2 useful, #3 aesthetic, #4 understandable, #5 unobtrusive, #6 honest, #8 thorough, #9 environmentally friendly, and #10 as little design as possible.

Verdict paragraph:
> The project needs a targeted systemic redesign, not an art reset: preserve the dark-fantasy assets, solver-safe puzzle core, five-realm content, and exact-resume foundation, but rebuild the layout, information, runtime, and progression systems around one coherent mobile contract.

Why redesign and not refine: the total is below 20/30 and the same fixed-layout, information-density, and runtime-coupling problems affect multiple primary screens and systems.

Preserve from current design:
- Solver-safe board generation and exact run/battle resume (`src/puzzle/board_factory.gd:42-73`, `src/ui/battle_screen.gd:115-159`).
- Dark-fantasy art direction, five-realm data, enemy intents/signatures, and honest New Mix cost (`data/areas.json`, `data/enemies.json`, `src/ui/battle_screen.gd:608-611`).

Discard:
- Fixed-width/fixed-floor screen geometry that clips area cards and places long-realm map nodes over headers (`src/ui/area_select_screen.gd:42-106`, `src/ui/dungeon_route.gd:198-201`). Caused failures on principles #2, #3, #4, and #10.
- Monolithic battle orchestration and synchronous per-move persistence/audio/FX work (`src/ui/battle_screen.gd:1-1122`, `src/autoload/save_system.gd:146-181`). Caused failures on principles #7 and #9.

Top moves:
1. Principles #2/#3/#10 — Responsive hierarchy: replace fixed-width area/map geometry with viewport- and grammar-driven layout; consolidate type, spacing, color, and touch tokens. Evidence: area selector/map captures and `src/ui/dungeon_route.gd:198-201`.
2. Principles #7/#9 — Runtime architecture: split the 1,122-line battle screen; coalesce main-thread saves; lazy-load audio; pool FX and cache generated textures. Evidence: `src/ui/battle_screen.gd:1-1122`, `src/autoload/save_system.gd:146-181`.
3. Principles #2/#6/#8 — Correct system contracts: route every hazard through one validated board-command API, repair corruption intent, and add production-wiring/latency/frame-budget tests in CI. Evidence: `src/battle/enemy_intent_controller.gd:72-78`, `src/puzzle/puzzle_board.gd:155-218`.
4. Principles #1/#2/#4 — Deeper procedural runs: use actual HP/build/repetition context and a serialized run RNG; turn Daily, Ascension, Mastery, events, and build synergies into authored systems. Evidence: `src/run/run_generator.gd:43`, `src/run/run_director.gd:11-15`.
5. Principles #3/#5/#9 — Purposeful presentation: give realms/enemies authored visual/audio identities, remove duplicate navigation and idle redraw, and make reduced-motion/accessibility settings comprehensive. Evidence: `src/ui/main_menu.gd:51-83`, `src/ui/ambient_particles.gd:29-47`.

Redesign principles in priority order:
1. Useful — every primary screen fits 576×1280 with no horizontal scroll or clipped action and exposes only current decisions.
2. Understandable — every label maps exactly to behavior and every tactical rule is available by tap.
3. Thorough — loading/error/focus/touch/reduced-motion/screen-reader states are first-class and regression-tested.

Deliverables:
- New information architecture with BattleScreen split boundaries.
- New primary flow compared side-by-side with current hall → area → map → battle → reward.
- Responsive specs for 576×1280 and 720×1280.
- Consolidated type/spacing/color/touch tokens.
- Save/audio/FX performance budgets and CI gates.
- States checklist: empty, loading, error, success, focus, disabled, reduced motion.
- Migration path preserving existing saves and active runs.
- Cutover criteria based on device frame time, save latency, APK size, and visual regression.

Anti-patterns:
- Porting the old fixed geometry under new textures.
- Adding more enemies before differentiating current systems.
- Keeping duplicate navigation or tooltip-only mobile information.
- Treating visual polish as a substitute for runtime profiling and accessibility.
```
