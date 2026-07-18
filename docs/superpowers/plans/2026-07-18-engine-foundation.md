# Engine Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee fair boards, make procedural pacing react to the live run, validate content, harden saves, and reduce battle orchestration risk before adding content.

**Architecture:** New pure RefCounted services own board creation/analysis, balance simulation, content validation, and run context. Existing public entry points remain compatible while `battle_screen.gd` delegates layout, overlays, and persistence to focused components.

**Tech Stack:** Godot 4.7.1, GDScript, JSON content, headless scene tests, PowerShell release tooling.

## Global Constraints

- Preserve exact resume for existing save boundaries and never relock existing Ascension progress.
- Every initial/remixed/transformed board must be solver-verified.
- Determinism is defined by seed plus persisted director decisions.
- No network telemetry or third-party runtime dependency.
- Use RED→GREEN TDD for every behavior change.

---

### Task 1: Board analysis and verified factory

**Files:**
- Create: `src/puzzle/board_difficulty.gd`
- Create: `src/puzzle/board_factory.gd`
- Modify: `src/puzzle/board_solver.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Test: `tests/board_factory_test.gd`
- Test: `tests/board_factory_test.tscn`

**Interfaces:**
- Produces: `BoardSolver.analyze(state: Array, max_states := 50000) -> Dictionary` with `solvable`, `estimated_moves`, `visited_states`.
- Produces: `BoardDifficulty.band(estimated_moves: int) -> String`.
- Produces: `BoardFactory.generate(seed: int, band: String, color_count := 4, capacity := 4, tube_count := 6) -> Dictionary` with `state`, `analysis`, `attempt`.
- Produces: `BoardFactory.remix(state: Array, seed: int, band := "standard") -> Dictionary`.

- [ ] **Step 1: Write failing solver/factory tests**

Assert a known solved state returns zero moves, a known impossible state returns `solvable=false`, identical seeds return identical verified boards, 500 generated boards are never already complete or unsolvable, and remix preserves the color multiset.

- [ ] **Step 2: Verify RED**

Run: `Godot_v4.7.1-stable_win64_console.exe --headless --path . tests/board_factory_test.tscn`

Expected: parse/API failures for missing `BoardFactory` and `BoardSolver.analyze`.

- [ ] **Step 3: Implement analysis and deterministic factory**

Use this result contract:

```gdscript
return {
    "solvable": solved_depth >= 0,
    "estimated_moves": solved_depth,
    "visited_states": visited.size(),
}
```

Factory retries deterministically, retains the closest verified candidate, and never returns an unverified shuffle.

- [ ] **Step 4: Route normal generation and New Mix through BoardFactory**

`PuzzleBoard.generate_board()` and remix retain their current signals/UI behavior but consume `result.state`; tutorial generation remains authored.

- [ ] **Step 5: Verify GREEN and regressions**

Run `board_factory_test.tscn`, `logic_test.tscn`, `board_transform_test.tscn`, `gameplay_integration_test.tscn`, and `mobile_feedback_regression_test.tscn`. Expected: zero failures.

- [ ] **Step 6: Commit**

Commit: `feat: guarantee solver-verified board difficulty`.

### Task 2: Deterministic balance laboratory

**Files:**
- Create: `src/testing/balance_simulator.gd`
- Create: `tests/balance_simulation_test.gd`
- Create: `tests/balance_simulation_test.tscn`
- Modify: `tools/validate_release.ps1`

**Interfaces:**
- Produces: `BalanceSimulator.simulate_board(seed: int, band: String) -> Dictionary`.
- Produces: `BalanceSimulator.simulate_encounter(enemy_id: String, area_id: String, ascension: int, seeds: int) -> Dictionary` with `samples`, `early_defeat_rate`, `mean_moves`, `mean_hp_delta`, `dead_board_rate`.
- Produces: `BalanceSimulator.matrix(area_ids: Array[String], ascensions: Array[int], seed_count: int) -> Dictionary`.

- [ ] Write RED tests for deterministic metrics, zero dead-board rate, and valid bounded ratios.
- [ ] Run the new scene and confirm missing-class failure.
- [ ] Implement a deterministic heuristic player using legal pours and solver distance; do not touch player save data.
- [ ] Add `-RunBalance` to the validator so the long matrix is opt-in locally and mandatory in release CI.
- [ ] Run 5,000 board samples and representative enemy/Ascension matrices; record thresholds in the test rather than hiding failures.
- [ ] Commit: `test: add deterministic balance laboratory`.

### Task 3: Runtime-aware director and segmented decisions

**Files:**
- Create: `src/run/run_context.gd`
- Create: `src/run/area_grammar.gd`
- Modify: `src/run/run_director.gd`
- Modify: `src/run/run_generator.gd`
- Modify: `src/autoload/run_state.gd`
- Test: `tests/run_director_test.gd`
- Modify: `tests/run_generation_test.gd`
- Modify: `tests/run_lifecycle_test.gd`

**Interfaces:**
- `RunContext.capture(run_state: Node) -> Dictionary` returns HP ratio, mean moves, recent damage, build score, kind streak, Ascension, and area.
- `RunDirector.choose_variant(node: Dictionary, context: Dictionary, decision_seed: int) -> Dictionary`.
- `RunState.resolve_reachable_variants() -> void` persists results under `run_graph.director_decisions`.

- [ ] Write RED tests proving low HP biases recovery, high build permits elite pressure, disclosed/selected/boss nodes never mutate, and a restored boundary produces identical variants.
- [ ] Run director, generation, and lifecycle tests; confirm failures against the current constant `hp_ratio` path.
- [ ] Implement immutable topology plus deterministic variants for unrevealed reachable nodes.
- [ ] Add boundary migration default `director_decisions={}` and retain old graphs unchanged.
- [ ] Run 10,000 route seeds across every current area; expect deterministic reachability and no combat-free route to boss.
- [ ] Commit: `feat: make run pacing respond to live context`.

### Task 4: Content schema and release version source

**Files:**
- Create: `src/data/content_validator.gd`
- Create: `data/release.json`
- Create: `tests/content_validation_test.gd`
- Create: `tests/content_validation_test.tscn`
- Modify: `src/autoload/game_state.gd`
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `tools/validate_release.ps1`

**Interfaces:**
- `ContentValidator.validate_all(content: Dictionary) -> Array[String]` returns stable `path: message` errors.
- `ContentValidator.validate_file(file_name: String, value: Variant) -> Array[String]`.
- `data/release.json` owns `version_name`, `version_code`, and `apk_name`.

- [ ] Write RED fixtures for missing enemy HP, unknown intent/signature, absent sprite, invalid area pool reference, unknown event operation, invalid boss action, and valid production data.
- [ ] Confirm the validator test fails because the class is missing.
- [ ] Implement explicit schemas/ranges and cross-reference checks; fallback loading remains for player safety, while tests/releases fail on invalid authored data.
- [ ] Add a version synchronization script/check that rejects divergence among release JSON, project metadata, preset, and filename.
- [ ] Run content, campaign, visual, and release budget tests. Expected: zero errors against the repository data.
- [ ] Commit: `build: validate content and unify release metadata`.

### Task 5: Generation/checksum save transaction

**Files:**
- Modify: `src/autoload/save_system.gd`
- Modify: `tests/save_recovery_test.gd`
- Modify: `tests/save_migration_test.gd`

**Interfaces:**
- `SaveSystem.payload_checksum(payload: Dictionary) -> String` excludes only the checksum field.
- `SaveSystem.validate_envelope(payload: Dictionary) -> bool`.
- `SaveSystem.load_from_paths(primary: String, backup: String) -> Dictionary` chooses the highest valid generation.

- [ ] Add RED cases for newer backup, truncated primary, bad checksum, failed replacement preserving a valid prior file, and migration idempotence.
- [ ] Confirm failures against version 7 save behavior.
- [ ] Add `generation` and `checksum`; verify every filesystem operation result; write and validate the replacement before retiring the prior primary.
- [ ] Preserve compatibility for unenveloped old saves by migrating once, then writing the new envelope.
- [ ] Run recovery, migration, lifecycle, encounter snapshot, and gameplay integration suites.
- [ ] Commit: `fix: make save commits generation-safe`.

### Task 6: Battle coordinator decomposition

**Files:**
- Create: `src/ui/battle_layout.gd`
- Create: `src/ui/battle_overlay_controller.gd`
- Create: `src/battle/battle_persistence.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/encounter_snapshot_test.gd`
- Modify: `tests/action_clarity_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- `BattleLayout.build(owner: Control, profile: Dictionary) -> Dictionary` returns named UI references.
- `BattleOverlayController.configure(host: Control, actions: VBoxContainer) -> void`; exposes `show_pause`, `show_victory`, `show_defeat`, `show_confirm`.
- `BattlePersistence.capture(screen: Node) -> Dictionary` and `restore(screen: Node, snapshot: Dictionary) -> bool`.

- [ ] Add RED component-contract tests and assert `battle_screen.gd` no longer owns overlay construction or snapshot field assembly.
- [ ] Run targeted tests and confirm missing class failures.
- [ ] Move behavior without changing strings, signals, ordering, node names, or snapshot schema.
- [ ] Verify pause/abandon/continue, reward, boss, tutorial, mobile, snapshot, and visual suites.
- [ ] Commit: `refactor: split battle coordination into focused services`.

### Task 7: Slice A gate

- [ ] Run fresh Godot import.
- [ ] Run every test scene and aggregate check/failure counts.
- [ ] Run long balance and content validation modes.
- [ ] Export a temporary Android debug APK and validate signature/budgets.
- [ ] Commit any gate-only tooling as `test: enforce engine foundation gates`.
