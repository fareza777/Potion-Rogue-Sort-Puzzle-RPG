# Production Polish, Progression, and Engine Hardening Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the approved roadmap after Combat Identity by improving HUD hierarchy, motion/audio feedback, build clarity, Ascension replayability, save reliability, and release regression coverage.

**Architecture:** Extract focused presentation components without replacing battle rules. Extend existing save/run/meta systems through additive versioned fields. Preserve offline Android compatibility and verify every behavior with focused RED-GREEN tests followed by the full suite.

**Tech Stack:** Godot 4.3+ GDScript, JSON data, GL Compatibility, Android export.

## Global Constraints

- Preserve version 6 saves and active-run snapshots.
- Keep exact enemy identity hidden before entering a route node.
- Minimum touch target remains 56 logical pixels.
- Both 720x1280 and 576x1280 must remain unclipped.
- Reduced Effects disables hit stop and high-amplitude motion.
- User music/SFX volume, including true mute, remains authoritative.
- Every production behavior begins with a failing test.

---

### Task 1: Responsive tactical readout component

**Files:**
- Create: `src/ui/tactical_readout.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/ui_component_test.gd`
- Modify: `tests/mobile_feedback_regression_test.gd`

**Interface:** `TacticalReadout.update_payload(objective: String, intent: Dictionary, trick: Dictionary) -> void`.

- [ ] Add RED assertions for a reusable readout, separate Objective/Next/Trick labels, 56 px minimum height, and 576-wide bounds.
- [ ] Implement a two-row responsive component: objective owns row one; intent and trick share row two with ellipsis and tooltips.
- [ ] Replace direct tactical label formatting in `battle_screen.gd` while preserving existing node names for test compatibility.
- [ ] Run UI, mobile, visual, combat, and snapshot suites; expect zero failures.
- [ ] Commit `feat: split battle tactical readout into responsive component`.

### Task 2: Impact motion and adaptive audio ducking

**Files:**
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/audio_test.gd`
- Modify: `tests/combat_overhaul_test.gd`

**Interfaces:**
- `BattleFx.impact_freeze(duration_ms: int) -> void`
- `AudioManager.duck_music(duration: float, depth_db: float) -> void`

- [ ] Add RED tests for both interfaces, clamped durations, reduced-effects bypass, music mute preservation, and bounded duck depth.
- [ ] Implement hit stop by temporarily setting scene-tree time scale and restoring it from a process-always timer; never exceed 90 ms.
- [ ] Implement Music bus duck/recovery without modifying saved volume.
- [ ] Trigger light freeze/duck only on enemy heavy attacks, critical hits, boss phases, and ultimates.
- [ ] Run audio, combat, mobile, and visual suites; commit `feat: add bounded impact motion and audio ducking`.

### Task 3: Build summary and Ascension

**Files:**
- Create: `src/ui/build_summary.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/run/meta_progression.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/run/run_generator.gd`
- Modify: `src/run/threat_budget.gd`
- Modify: `tests/meta_progression_test.gd`
- Modify: `tests/run_generation_test.gd`
- Modify: `tests/save_migration_test.gd`

**Interfaces:**
- `MetaProgression.ascension_unlocked() -> bool`
- `MetaProgression.max_ascension() -> int`
- `BuildSummary.configure(kit_id: String, relics: Array, upgrades: Array, mutations: Array) -> void`
- `RunGenerator.generate(seed: int, area_id: String, ascension: int = 0) -> Dictionary`

- [ ] Add RED tests: all three cleared areas unlock Ascension 1; ascension clamps 0-10; graph stores level; same seed+level is deterministic; level changes threat but not early enemy tiers; v6 migration defaults to zero.
- [ ] Add save version 7 fields `max_ascension` and `selected_ascension`; migrate and validate them.
- [ ] Persist run ascension in boundary snapshots and history. Apply +4% enemy vitality per level, an elite chance increase capped at 30%, and additional modifiers only after level 2.
- [ ] Add an Ascension selector to expedition screen only when unlocked.
- [ ] Replace the map's single BUILD text line with a compact scroll-free build summary using kit, counts, strongest synergy, and a tooltip-expanded detail panel.
- [ ] Run meta, generation, migration, lifecycle, visual, and mobile tests; commit `feat: add build summary and ascension progression`.

### Task 4: Atomic save with backup recovery

**Files:**
- Modify: `src/autoload/save_system.gd`
- Modify: `tests/save_migration_test.gd`
- Create: `tests/save_recovery_test.gd`
- Create: `tests/save_recovery_test.tscn`

**Interfaces:**
- Save paths: `user://save.json`, `user://save.tmp`, `user://save.backup.json`.
- `SaveSystem.parse_save_text(text: String) -> Dictionary`
- `SaveSystem.write_atomic(payload: Dictionary) -> bool`

- [ ] Add RED tests for corrupt primary fallback, valid backup recovery, temp cleanup, and schema rejection.
- [ ] Serialize to temp, flush, rotate valid primary to backup, then rename temp to primary.
- [ ] Load primary first, backup second, defaults last; never overwrite the backup with corrupt data.
- [ ] Keep public `save()` behavior compatible and return no exception.
- [ ] Run recovery, migration, lifecycle, encounter, and full logic suites; commit `fix: make local saves atomic and recoverable`.

### Task 5: Visual regression and final release

**Files:**
- Modify: `src/autoload/dev_tools.gd`
- Modify: `tests/mobile_feedback_regression_test.gd`
- Modify: `tests/release_budget_test.gd`
- Modify: `export_presets.cfg`

- [ ] Add RED checks for deterministic capture phases, signature/boss capture helpers, and release audio budget.
- [ ] Add DevTools phase preparation that sets MAP/BATTLE without touching the user's live run save.
- [ ] Capture Hall, map, first battle, signature trigger, boss phase, pause, reward, settings, workshop, and build summary at both portrait widths.
- [ ] Fix every observed overlap or clipping regression and rerun all suites.
- [ ] Increment Android version code/name, export final APK, validate budgets/signature, and record SHA-256.
- [ ] Commit `release: complete production polish roadmap`.

