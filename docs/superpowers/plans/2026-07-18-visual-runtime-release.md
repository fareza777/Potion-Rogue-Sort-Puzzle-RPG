# Visual Runtime and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the visual system, improve battle motion and accessibility, remove waste, add perceptual/runtime gates, and deliver a verified five-realm APK.

**Architecture:** One semantic token source feeds all reusable components. Lightweight profile animation consumes authored enemy metadata, pooled FX control runtime cost, and capture/performance tools validate rendered results rather than source strings alone.

**Tech Stack:** Godot 4.7.1 Compatibility renderer, GDScript, image/audio import tooling, screenshot baselines, Android emulator/apksigner.

## Global Constraints

- Preserve approved backgrounds, original enemy art, Hall composition, bottle family, and core gold/purple identity.
- No decision-critical text below 13px; route/tactical action copy is at least 14px at 720 baseline.
- Every interactive target is at least 56×56px.
- No symbols inside potion liquid.
- Reduced Effects preserves telegraph clarity while removing shake/hit-stop and lowering particles.
- Final APK ≤70 MiB.

---

### Task 1: One semantic token and component system

**Files:**
- Modify: `src/ui/ui_theme_tokens.gd`
- Modify: `src/ui/ui_kit.gd`
- Modify: `src/ui/components/action_icon_button.gd`
- Modify: `src/ui/components/bottom_nav.gd`
- Modify: `src/ui/ornate_resource_bar.gd`
- Create: `tests/design_system_test.gd`
- Create: `tests/design_system_test.tscn`
- Modify: `tests/ui_component_test.gd`

**Interfaces:**
- Tokens expose semantic colors, type roles, spacing, radii, border widths, shadows, durations, and `touch_size()`.
- UiKit references tokens; duplicate base color constants become compatibility aliases only during migration and are removed before the task ends.

- [ ] Write RED tests for ≤12 semantic colors, exact type roles, route/tactical minimums, consistent focus/disabled/selected styles, and 56px component targets.
- [ ] Confirm dual-system/ad-hoc component failures.
- [ ] Migrate reusable factories first; preserve node names and visual asset textures.
- [ ] Run design, UI, accessibility, action, and visual suites after each component family.
- [ ] Commit: `refactor: unify premium mobile design tokens`.

### Task 2: Screen readability and accessibility

**Files:**
- Create: `src/ui/components/state_panel.gd`
- Create: `src/ui/components/loadout_sheet.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/ui/tactical_readout.gd`
- Modify: `src/ui/build_summary.gd`
- Modify: `src/ui/tutorial.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/accessibility_test.gd`
- Modify: `tests/mobile_feedback_regression_test.gd`

**Interfaces:**
- Settings add `text_scale` (`1.0`, `1.15`, `1.30`) and `high_contrast`.
- `UiThemeTokens.scaled_type(role: String, scale: float) -> int`.
- `StatePanel.configure(kind: String, title: String, body: String, retry := Callable())`.

- [ ] Add RED tests for every target size, scaled text containment, contrast tokens, full focus order, selected-color name, no tooltip-only build detail, and reusable empty/loading/error/success/resumed states.
- [ ] Confirm failures for 9–12px map/tactical copy and undersized controls.
- [ ] Raise copy sizes, simplify repeated legend/chrome, move boss status outside sprite bounds, and distinguish selected/focused/disabled/locked states.
- [ ] Replace flat potion halos with rim/pedestal feedback; add explicit selected color text outside the liquids.
- [ ] Add high-contrast/text-scale controls; retain clean potion liquid with no glyph rendering.
- [ ] Run accessibility, mobile, UI, battle, tutorial, map, and visual suites.
- [ ] Commit: `feat: make five-realm UI readable and accessible`.

### Task 3: Enemy-specific motion and pooled battle FX

**Files:**
- Create: `src/ui/fx_pool.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/ui/ambient_particles.gd`
- Modify: `tests/combat_overhaul_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Motion profiles: `skitter`, `duelist`, `predator`, `ritual`, `heavy`, `spectral`, `floating`, `leviathan` plus legacy mappings.
- `EnemyDisplay.action_anchor(kind: String) -> Vector2`.
- `FxPool.acquire(kind: String) -> Node2D`, `release(node: Node2D)`, `active_count()`, `capacity()`.

- [ ] Write RED tests for every profile/action, authored impact/projectile anchors, pool capacity/reuse, obscured-process pause, reduced-effects bounds, and route with no periodic full redraw.
- [ ] Confirm missing profiles/pool and redraw behavior fail.
- [ ] Implement lightweight transform curves for idle/anticipate/attack/hit/signature/phase/defeat; do not add skeletal dependency.
- [ ] Pool temporary VFX and cap full/reduced counts; release every borrowed node after animation.
- [ ] Replace route 25Hz redraw with tweened glow properties and pause ambient/enemy processing behind blocking overlays.
- [ ] Run combat, boss, mobile, reduced-effects, visual, and leak-focused repeated-battle tests.
- [ ] Commit: `perf: add authored motion with bounded pooled effects`.

### Task 4: Curated asset and audio export

**Files:**
- Modify: `export_presets.cfg`
- Modify: `tools/validate_release.ps1`
- Modify: relevant `.import` settings under `assets/art/`
- Modify: `tests/release_budget_test.gd`
- Create: `tools/audit_runtime_assets.ps1`

- [ ] Add RED checks for orphan runtime assets, forbidden atlases/source masters, PNG dimensions, OGG loop files, APK 70 MiB cap, and exported resource manifest.
- [ ] Confirm the four legacy atlases and all-resources policy fail the new audit.
- [ ] Remove only verified-unreferenced atlases/duplicate icons from export, preserve user attachments and source documents, and curate runtime include/exclude rules.
- [ ] Downscale oversized runtime copies after side-by-side captures; apply mobile compression only when alpha edges and the Cave Slime benchmark remain clean.
- [ ] Convert long ambience masters to looped OGG and keep masters outside export.
- [ ] Export checkpoint APK, inspect contents, and run budget/visual comparisons.
- [ ] Commit: `perf: curate five-realm Android assets`.

### Task 5: Screenshot and runtime regression harness

**Files:**
- Modify: `src/autoload/dev_tools.gd`
- Create: `tools/capture_visual_matrix.ps1`
- Create: `tools/compare_screenshots.ps1`
- Create: `tests/visual_baseline_test.gd`
- Create: `tests/visual_baseline_test.tscn`
- Create: `tests/runtime_budget_test.gd`
- Create: `tests/runtime_budget_test.tscn`
- Modify: `.github/workflows/android-release-gates.yml`

**Interfaces:**
- DevTools capture phases add area/map/T1/elite/boss phase/pause/tutorial/reward/event/settings/history/mastery/build sheet.
- Baseline manifest records viewport, scene, state args, approved image hash, masks, and pixel-diff threshold.
- Runtime report records `fps_min`, `frame_p95_ms`, `peak_nodes`, FX cache sizes, audio playing/dropout state.

- [ ] Add RED tests requiring the complete five-realm capture matrix and runtime budget schema.
- [ ] Confirm current source-contract visual tests cannot satisfy baselines.
- [ ] Build deterministic capture states that never mutate the user's save.
- [ ] Capture and approve both 576×1280 and 720×1280 baselines only after manual inspection.
- [ ] Compare images with small masks for nondeterministic particle pixels; clipping/text/status regions have strict thresholds.
- [ ] Add a 120-second repeated battle/map runtime sample and fail on unbounded node/cache growth.
- [ ] Run harness locally and in CI.
- [ ] Commit: `test: add perceptual and runtime Android gates`.

### Task 6: Five-realm visual iteration

- [ ] Capture Hall, five maps, five intro enemies, five bosses, pause, tutorial, reward, event, settings, history, Mastery, Ascension, and build sheet at both widths.
- [ ] Inspect: clipping, status overlap, 56px targets, text minimums, frame consistency, dark-stage contrast, enemy baseline, button state distinction, safe margins, and tutorial target relation.
- [ ] Fix one observed defect at a time with a RED baseline/component test before production edits.
- [ ] Repeat captures until every strict region passes and no approved illustration is degraded.
- [ ] Commit coherent visual fixes by component, not one unreviewable bulk commit.

### Task 7: Final release

**Files:**
- Modify: `release/version.json`
- Modify generated version consumers through `tools/sync_version.ps1`
- Create: `docs/releases/1.2.0.md`

- [ ] Set release `1.2.0`, code `13`, APK `builds/PotionRogue-v13-debug.apk`.
- [ ] Run version check, fresh import, every test scene, long board/route/combat simulations, content validation, screenshot comparisons, runtime sample, and `git diff --check`.
- [ ] Export Android debug APK and verify package, embedded version, v2/v3 signature, APK ≤70 MiB, resource manifest, and SHA-256.
- [ ] Install/smoke on emulator: cold launch, five-area unlock path, exact battle resume, background/restore, audio interruption, pause/save/exit, abandon/continue, Daily claimed, text scale, high contrast, and both new bosses.
- [ ] Merge only after the full matrix passes on the merged result; preserve unrelated user changes.
- [ ] Commit release notes/version as `release: deliver Potion Rogue five-realm v1.2.0` and push `main`.
