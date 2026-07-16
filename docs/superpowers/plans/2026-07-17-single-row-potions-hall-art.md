# Single-Row Potions and Hall Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a large single-row potion board and ship a richer generated main-hall background with restrained ornament polish.

**Architecture:** PuzzleBoard owns a six-column shelf layout without an enclosing panel. MainMenu consumes a dedicated generated background through VisualRegistry while keeping the slime, title, controls, and animation as independent UI layers.

**Tech Stack:** Godot 4.7.1, GDScript, built-in image generation, PNG assets, headless tests, screenshot QA, Android export.

## Global Constraints

- Preserve gameplay rules, tube order, touch behavior, and monster sprites.
- Target tall 576x1280 Android devices and standard 720x1280 portrait.
- Generated art must contain no text, logo, character, UI, or watermark.
- Never leave a project-referenced generated image outside the workspace.

---

### Task 1: Single-Row Potion Shelf

**Files:**
- Modify: `tests/visual_test.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/puzzle/potion_tube.gd`

**Interfaces:**
- Produces: `layout_columns() -> int` returning `6`, `tube_display_size() -> Vector2`, and named `PotionShelf`.

- [ ] Add failing visual contracts for six columns, `PotionShelf`, absence of `AlchemyTray`, and bottle width at least 96.
- [ ] Run the visual suite and confirm the contracts fail against the 3-by-2 tray.
- [ ] Replace GridContainer configuration with six columns, remove the panel/title, and build a transparent shelf holder with a subtle horizontal ornament.
- [ ] Increase tall-profile bottle size to fit six across the safe width and retain an 84-pixel minimum touch target.
- [ ] Capture battle at the device ratio and iterate until bottles and controls do not overlap.
- [ ] Run both suites and commit `ui: restore large single-row potion shelf`.

### Task 2: Generated Main Hall Background

**Files:**
- Create: `assets/art/backgrounds/main_hall_v2.png`
- Modify: `src/ui/visual_registry.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Produces: `VisualRegistry.background("main_hall") -> String` and project-owned PNG art.

- [ ] Add failing contracts for the new background mapping and main-menu usage.
- [ ] Generate a portrait dark-fantasy hall background using the existing hall as a style reference and save the selected output into the workspace.
- [ ] Inspect the output for center readability, safe negative space, absence of text/UI/watermark, and coherent palette.
- [ ] Register and consume the background without baking the slime or controls into it.
- [ ] Capture the hall screen and iterate once on art or overlays if hierarchy is weak.
- [ ] Run the visual suite and commit `art: add generated premium main hall background`.

### Task 3: Ornament and Layout QA

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/battle_screen.gd` only if screenshot QA requires it.
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Preserves all public gameplay APIs.

- [ ] Add source contracts for named `HallCrest` and `PotionShelfOrnament` controls.
- [ ] Add restrained crest/shelf ornament layers using existing textures and code-native styles.
- [ ] Capture hall, battle, map, settings, workshop, and credits screenshots.
- [ ] Remove any visible overlap, excessive box, or clipped bottom navigation found in the captures.
- [ ] Run 33 logic checks and the complete visual suite with zero failures.
- [ ] Commit `ui: refine hall and battle ornament hierarchy`.

### Task 4: APK v4 and Integration

**Files:**
- Output: `builds/PotionRogue-debug-v4.apk`

- [ ] Export Android Debug from the clean feature branch.
- [ ] Validate package name and SDK metadata with `aapt` and record SHA-256.
- [ ] Merge to `main`, re-run both suites, export the final APK from `main`, and push.

