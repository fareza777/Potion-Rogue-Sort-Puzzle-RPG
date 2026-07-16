# Premium Battle HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a premium, reference-quality battle HUD and hall composition with proportional 3-by-2 potion bottles.

**Architecture:** Introduce focused presentation controls for framed resource bars and the alchemy tray, while keeping battle and puzzle state in the existing managers. PuzzleBoard owns responsive tube placement; BattleScreen composes HUD components; MainMenu owns hall-only visual atmosphere.

**Tech Stack:** Godot 4.7.1, GDScript, deterministic CanvasItem drawing, existing PNG art, headless scene tests, DevTools screenshots, Android debug export.

## Global Constraints

- Preserve all existing gameplay rules and monster assets.
- Target 576x1280 and standard 720x1280 portrait layouts.
- Maintain minimum 84-pixel touch targets in design coordinates.
- Preserve reduced-effects behavior.
- Use test-first implementation and visually inspect every changed screen.

---

### Task 1: Responsive 3-by-2 Potion Tray

**Files:**
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/puzzle/potion_tube.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces: `PuzzleBoard.layout_columns() -> int`, `PuzzleBoard.tube_display_size() -> Vector2`, and a named `AlchemyTray` control.

- [ ] Add visual contract checks that expect three columns, bottle aspect between 0.38 and 0.48, and an `AlchemyTray` node contract.
- [ ] Run the visual suite and confirm the new checks fail because the APIs do not exist.
- [ ] Replace the one-row HBox with a centered two-row GridContainer, use proportional bottle sizes, and add a tray backdrop that does not consume input.
- [ ] Add selected-bottle lift and glow without changing pour logic.
- [ ] Run both suites and capture a 576x1280 battle screenshot.
- [ ] Commit with `ui: arrange potion bottles on premium alchemy tray`.

### Task 2: Framed Resource HUD

**Files:**
- Create: `src/ui/ornate_resource_bar.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/ui_kit.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces: `OrnateResourceBar.configure(kind: String, title: String)`, `set_values(value: float, maximum: float)`, and `set_badge(text: String)`.

- [ ] Add checks for the resource-bar API and named `EnemyVitalBar` / `PlayerVitalBar` battle contracts.
- [ ] Run the visual suite and confirm failure for the missing class and names.
- [ ] Build the layered bar with obsidian track, gold frame, colored fill, inner sheen, marker glyph, centered value, and optional badge.
- [ ] Replace loose ProgressBar and shield text composition in BattleScreen while retaining tweened updates and coordinate helpers.
- [ ] Run both suites and capture tall and standard battle screenshots.
- [ ] Commit with `ui: replace flat battle bars with framed resource hud`.

### Task 3: Battle Typography and Action Polish

**Files:**
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/ui_kit.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces named `EncounterHeader`, `WarningPlaque`, and `ActionPedestal` controls.

- [ ] Add source-contract checks for the three named presentation components.
- [ ] Run the visual suite and confirm expected failures.
- [ ] Recompose the stage/name/currency hierarchy, build a countdown plaque, tighten turn/instruction spacing, and add identical action pedestals.
- [ ] Add warning pulse and bar shimmer that honor reduced-effects.
- [ ] Run suites and inspect screenshots for overlap, empty zones, and baseline symmetry.
- [ ] Commit with `ui: refine battle typography and action hierarchy`.

### Task 4: Hall Hero and Safe Navigation

**Files:**
- Modify: `src/ui/main_menu.gd`
- Create: `src/ui/ambient_particles.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces named `HeroHalo`, `FeatureSeals`, and `SafeNavigation` controls; `AmbientParticles.set_reduced_effects(value: bool)`.

- [ ] Add contract checks for the named hall controls and particle API.
- [ ] Run the visual suite and confirm expected failures.
- [ ] Add restrained halo/embers, three feature seals, and a bottom composition that remains inside the safe area.
- [ ] Capture 576x1280 and 720x1280 hall screenshots and iterate until no controls are clipped.
- [ ] Run both suites.
- [ ] Commit with `ui: enrich hall hero and safe navigation`.

### Task 5: Visual QA, Android Export, and Integration

**Files:**
- Modify only files required by screenshot QA.
- Output: `builds/PotionRogue-debug-v3.apk`

- [ ] Capture hall, battle, map, settings, workshop, and credits at 576x1280.
- [ ] Compare bottle proportions, HUD readability, safe areas, and design consistency against the approved spec; iterate on visible defects.
- [ ] Run `logic_test.tscn` and require 0 failures.
- [ ] Run `visual_test.tscn` and require 0 failures.
- [ ] Export Android Debug to `builds/PotionRogue-debug-v3.apk`.
- [ ] Validate package metadata with `aapt`, compute SHA-256, merge to `main`, re-run tests, and push.

