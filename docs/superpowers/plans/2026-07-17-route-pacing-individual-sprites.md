# Route Pacing and Individual Sprites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee meaningful combat pacing on every procedural route and replace shared atlas slices with twenty clean individual enemy sprites.

**Architecture:** Run generation assigns floor-level cadence before decorating encounters, making the pacing invariant independent of links. Enemy presentation follows the established direct-sprite path; generated individual PNGs are referenced from enemy data and the atlas resolver remains fallback-only.

**Tech Stack:** Godot 4.7.1, GDScript, JSON content data, PNG alpha assets, built-in image generation.

## Global Constraints

- Every start-to-boss route has at least three pre-boss combat nodes.
- No route has consecutive non-combat nodes.
- Floors 1, 3, and 5 are combat-only; floors 2 and 4 contain exactly one non-combat node.
- Each of the twenty generated enemies uses one individual transparent PNG.
- Preserve seeded determinism and 12–15 total nodes.

---

### Task 1: Encode pacing invariants as failing tests

**Files:**
- Modify: `tests/run_generation_test.gd`

**Interfaces:**
- Consumes: `RunGenerator.generate(seed: int) -> Dictionary`
- Produces: `_all_routes_have_combat_cadence(graph: Dictionary) -> bool`

- [ ] Add assertions for floor composition and recursively inspect every route for three combats and maximum one non-combat streak.
- [ ] Run `Godot --headless --path . tests/run_generation_test.tscn` and confirm failure on the current generator.

### Task 2: Implement deterministic floor cadence

**Files:**
- Modify: `src/run/run_generator.gd`
- Test: `tests/run_generation_test.gd`

**Interfaces:**
- Produces: `_kind_for_node(floor: int, slot: int, noncombat_slot: int, rng: RandomNumberGenerator) -> String`

- [ ] Choose one non-combat slot only on floors 2 and 4; emit combat everywhere else.
- [ ] Keep floor 1 normal battle and permit elite variants only on later combat floors.
- [ ] Run the 2,000-seed generation test and confirm zero failures.
- [ ] Commit the pacing change.

### Task 3: Encode individual-sprite contract as a failing test

**Files:**
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: `VisualRegistry.enemy(enemy_id)` and `VisualRegistry.enemy_texture(enemy_id)`
- Produces: a resource contract requiring `sprite` and forbidding runtime `atlas` for the twenty generated enemies.

- [ ] Add assertions for a direct loadable sprite path on each enemy carrying generated art.
- [ ] Run `tests/visual_test.tscn` and confirm it fails because those enemies currently expose atlas regions.

### Task 4: Generate and integrate twenty individual sprites

**Files:**
- Create: `assets/art/enemies/generated/*.png` (twenty files)
- Modify: `data/enemies.json`
- Modify: `src/ui/visual_registry.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces: `sprite: res://assets/art/enemies/generated/<enemy_id>.png` per enemy.

- [ ] Generate one isolated full-body asset per enemy using the family atlas only as style/identity reference.
- [ ] Remove chroma backgrounds with the installed imagegen helper and validate transparent corners and complete subject coverage.
- [ ] Replace atlas fields in enemy data with direct sprite fields and merge the data path in `VisualRegistry.enemy()`.
- [ ] Import assets and run visual tests to zero failures.
- [ ] Capture representative battles for crypt, fungal, arcane, and infernal enemies; regenerate any cropped or contaminated result.
- [ ] Commit the sprite change.

### Task 5: Full verification and Android delivery

**Files:**
- Create: `builds/PotionRogue-v7-debug.apk` (ignored delivery artifact)

- [ ] Run all `tests/*_test.tscn` scenes and require zero failures.
- [ ] Export and verify the signed debug APK with `apksigner`.
- [ ] Merge to `main`, rerun targeted tests, push `main`, and retain the APK at the main workspace path.
