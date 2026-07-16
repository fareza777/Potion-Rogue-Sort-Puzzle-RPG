# Mobile Polish and Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a dense, responsive, polished mobile presentation with an illustrated dungeon route, coherent iconography, original ambience, richer combat feedback, and a forgiving opening battle.

**Architecture:** Add viewport-derived presentation profiles to `UiKit`, keep gameplay state authoritative in existing managers, and isolate the new route renderer and audio assets behind small interfaces. All screen compositions consume ratios from the shared profile while retaining their current navigation and signals.

**Tech Stack:** Godot 4.7.1, GDScript, generated transparent PNG UI assets, original PCM WAV ambience, headless Godot tests, Android debug export.

## Global Constraints

- Support 16:9, 19.5:9, 20:9, 22:9, and the 576×1280 phone acceptance viewport.
- Preserve puzzle rules, run structure, rewards, and saved progression.
- Keep all interactive controls inside safe margins while backgrounds bleed edge-to-edge.
- Keep reduced-effects support and never let presentation mutate combat state.
- Opening Cave Slime target: 70–80% HP remaining for a typical tutorial path.

---

### Task 1: Responsive Presentation Profile

**Files:**
- Modify: `src/ui/ui_kit.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `UiKit.layout_profile(viewport_size: Vector2) -> Dictionary`
- Produces: `UiKit.safe_margin(parent: Control, horizontal := 24, top := 28, bottom := 24) -> MarginContainer`

- [ ] Add failing tests asserting that 720×1280 returns `standard`, 576×1280 returns `tall`, all band ratios sum to 1.0, and margins remain at least 20 px.
- [ ] Run `Godot --headless --path . res://tests/visual_test.tscn`; expect the new profile checks to fail.
- [ ] Implement profiles containing `hero_ratio`, `arena_ratio`, `board_ratio`, `controls_ratio`, and safe margins. Tall profiles allocate extra height to hero/board rather than blank spacers.
- [ ] Run visual tests; expect all checks to pass.
- [ ] Commit with `feat: add responsive portrait layout profiles`.

### Task 2: Coherent Utility Icon Pack

**Files:**
- Create: `assets/art/ui/icon_music.png`
- Create: `assets/art/ui/icon_sound.png`
- Create: `assets/art/ui/icon_vibration.png`
- Replace: `assets/art/ui/icon_undo.png`
- Replace: `assets/art/ui/icon_remix.png`
- Replace: `assets/art/ui/icon_pause.png`
- Modify: `src/ui/visual_registry.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `VisualRegistry.ui_icon(icon_id: String) -> String`

- [ ] Add failing coverage for all six IDs and exact 512×512 transparent resource dimensions.
- [ ] Generate six isolated obsidian-and-antique-gold icons with identical circular framing, optical center, stroke weight, and 14% transparent safe padding.
- [ ] Remove chroma keys with soft matte/despill and inspect each output at original resolution.
- [ ] Register the paths and update `UiKit.icon_button()` so count badges and captions do not affect icon centering.
- [ ] Run visual tests and capture a control-row screenshot.
- [ ] Commit with `art: replace utility controls with centered icon set`.

### Task 3: Full-Height Menu and Utility Screens

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/credits_screen.gd`
- Modify: `src/ui/shop_screen.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: `UiKit.layout_profile()` and `UiKit.ui_icon()`.

- [ ] Add scene contract checks for named full-height bands and icon-led settings rows.
- [ ] Recompose main menu into title, hero, pitch, primary action, utilities, and currency bands using expand flags derived from the profile.
- [ ] Rebuild settings as three equal icon-led rows with aligned labels, themed sliders, live percentages, and vibration toggle.
- [ ] Make credits and workshop panels use bounded proportional height instead of fixed centered content.
- [ ] Capture 720×1280 and 576×1280 screenshots for all four scenes; verify no lower dead zone and no clipping.
- [ ] Commit with `feat: make meta screens fill tall phones`.

### Task 4: Illustrated Dungeon Route

**Files:**
- Create: `src/ui/dungeon_route.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `DungeonRoute.configure(entries: Array, current_index: int) -> void`
- Produces: signal `node_pressed(index: int)` for the current node only.

- [ ] Add failing tests for seven medallions, a larger boss node, current/locked/cleared states, and portrait texture use.
- [ ] Implement a custom route control that draws a curved glowing path and positions alternating medallions by normalized coordinates.
- [ ] Use registered enemy portraits inside clipped medallions; add pulse tween only to the current node.
- [ ] Pin status and Enter Battle to the lower safe region while the route expands between header and status.
- [ ] Capture standard/tall screenshots and inspect portrait crop, path continuity, and touch targets.
- [ ] Commit with `feat: replace battle list with illustrated dungeon route`.

### Task 5: Opening Difficulty Curve

**Files:**
- Modify: `data/enemies.json`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/logic_test.gd`

**Interfaces:**
- Produces: `PuzzleBoard.generate_tutorial_board() -> void`

- [ ] Add failing tests expecting Cave Slime attack 5, cadence 4, and a tutorial layout with immediate legal progress toward green or blue.
- [ ] Change Cave Slime stats to 5 damage every 4 moves and call the deterministic tutorial generator only for a first-run battle zero.
- [ ] Keep random generation for returning players and every later encounter.
- [ ] Add a deterministic scripted tutorial-path test asserting remaining HP between 35 and 40 after the expected opening exchange.
- [ ] Run all logic tests and commit with `balance: soften the opening Cave Slime battle`.

### Task 6: Responsive Battle Composition and Motion

**Files:**
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/ui_kit.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `BattleFx.projectile(from: Vector2, to: Vector2, color: Color, kind: String)`
- Produces: `BattleFx.telegraph(target: Control, color: Color)`
- Produces: `UiKit.animate_bar(bar: ProgressBar, value: float, duration := 0.24)`

- [ ] Add failing interface and reduced-effects tests for telegraph, projectile, and animated bars.
- [ ] Recompose battle into arena/status/board/action bands. Scale enemy and tubes within bounded profile ratios and remove the expanding empty spacer.
- [ ] Add breathing/hover loops by motion profile, attack telegraphs, projectile trails, layered impact rings/sparks, HP interpolation, and button press depth.
- [ ] Keep camera shake ≤8 px normally and ≤3 px in reduced effects.
- [ ] Capture idle, hit, and boss screenshots at standard and tall viewports; run visual and logic tests.
- [ ] Commit with `feat: enrich responsive battle presentation`.

### Task 7: Original Ambient Music and Crossfade

**Files:**
- Create: `assets/audio/dungeon_ambient.wav`
- Create: `assets/audio/boss_ambient.wav`
- Create: `tools/build_ambient_audio.ps1`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `AudioManager.crossfade_music(track: String, duration := 1.2) -> void`

- [ ] Add failing tests that both WAV files load, loop metadata is valid, peaks stay below -1 dBFS, and crossfade interface exists.
- [ ] Author 44.1 kHz stereo seamless loops: dungeon uses drones, filtered noise, sparse crystal bells, and restrained pulse; boss adds darker harmony and stronger rhythm.
- [ ] Replace the single player with two Music-bus players and equal-power crossfade tweens. Retain synthesized sound effects as fallback.
- [ ] Verify no restart when requesting the current track and no state dependency on playback.
- [ ] Commit with `audio: add original ambient score and crossfades`.

### Task 8: Device QA, Documentation, and APK

**Files:**
- Modify: `README.md`
- Modify: `docs/ART_PIPELINE.md`
- Update: `store-assets/screenshots/*.png`
- Rebuild: `store-assets/play-store-feature-graphic.png`

- [ ] Import assets and run fresh logic and visual suites.
- [ ] Smoke-test main menu, map, battle, shop, settings, and credits.
- [ ] Capture acceptance screenshots at 720×1280 and 576×1280-equivalent tall layouts; inspect every control and text baseline.
- [ ] Regenerate truthful store screenshots and feature graphic from the revised scenes.
- [ ] Export `builds/PotionRogue-debug-v2.apk`, verify APK signature/package/version, and compute SHA-256.
- [ ] Run `git diff --check`, commit with `release: deliver mobile polish APK`, and push `main`.
