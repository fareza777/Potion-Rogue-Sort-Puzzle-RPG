# Map Fog and Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide future route content, pace enemy tiers, add safe Hall navigation, and polish the route map.

**Architecture:** Keep generated encounter truth inside `RunState.run_graph`; disclosure is presentation-only in `DungeonRoute`. Keep progression selection inside `RunGenerator`, and keep scene navigation inside `MapScreen`.

**Tech Stack:** Godot 4.7.1, GDScript, existing UiKit, headless scene tests, DevTools screenshots, Android debug export.

## Global Constraints

- Do not reveal future node kind, event id, enemy id, name, or portrait.
- Returning to Hall must preserve the active run.
- Preserve combat-heavy cadence and deterministic generation.
- Do not add dependencies or replace the existing generated art style.

---

### Task 1: Enemy floor progression

**Files:**
- Modify: `tests/run_generation_test.gd`
- Modify: `src/run/run_generator.gd`

- [ ] Add assertions that floor 1 uses only `slime`/`skeleton`, floor 2 stays tier 1, floor 3–4 stay tier 2 for normal battle, and floor 5 stays tier 3.
- [ ] Run `run_generation_test.tscn` and verify the new assertions fail.
- [ ] Implement an explicit floor-to-tier policy with a classic-only floor-1 pool.
- [ ] Re-run the test and commit the green progression change.

### Task 2: Fog-of-war disclosure

**Files:**
- Modify: `tests/visual_test.gd`
- Modify: `src/ui/dungeon_route.gd`

- [ ] Add source-contract tests for `UNCHARTED`, `UNKNOWN ENCOUNTER`, and absence of future portrait rendering.
- [ ] Run `visual_test.tscn` and verify failure.
- [ ] Add disclosure state helpers and render mystery cards for reachable/future nodes while revealing visited history only.
- [ ] Re-run the visual test and commit the green disclosure change.

### Task 3: Hall navigation and map polish

**Files:**
- Modify: `tests/visual_test.gd`
- Modify: `src/ui/map_screen.gd`

- [ ] Add tests requiring `BackToHallButton`, `UNCHARTED ROUTE`, and a handler that only changes scene.
- [ ] Run `visual_test.tscn` and verify failure.
- [ ] Add a premium header action, depth subtitle, legend, and non-destructive return handler.
- [ ] Re-run the visual test, capture `map.tscn` at 720x1280, and iterate spacing if needed.

### Task 4: Release verification

**Files:**
- Create: `builds/PotionRogue-v8-debug.apk` (ignored artifact)

- [ ] Run every `tests/*test.tscn` scene and require zero failures.
- [ ] Export Android Debug and verify APK signature schemes v2/v3.
- [ ] Merge to `main`, re-run the full suite, push, then clean the worktree.
