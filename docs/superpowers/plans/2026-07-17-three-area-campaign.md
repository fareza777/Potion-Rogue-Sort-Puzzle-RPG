# Three-Area Campaign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship three independently replayable procedural areas with persistent unlocks, distinct enemies/bosses/backgrounds/audio, and a truthful completion flow.

**Architecture:** `data/areas.json` is the single content definition. `GameState` exposes area data, `RunGenerator` consumes one area config, `RunState` owns the selected active area, and `SaveSystem` owns permanent unlock/completion state. UI reads area state without hard-coded boss/background branches.

**Tech Stack:** Godot 4.7.1, typed GDScript, JSON content, generated PNG/WAV assets, headless scene tests, Android compatibility renderer.

## Global Constraints

- Preserve deterministic generation and combat-heavy seven-depth routes.
- Preserve existing player currency, upgrades, tutorial, and legacy active runs through save migration.
- Do not add third-party runtime dependencies or network requirements.
- New areas must remain beatable without permanent upgrades.
- Use existing individual enemy sprites; only area backgrounds and audio are newly generated.

---

### Task 1: Area content registry

**Files:**
- Create: `data/areas.json`
- Modify: `src/autoload/game_state.gd`
- Create: `tests/campaign_test.gd`
- Create: `tests/campaign_test.tscn`

**Interfaces:**
- Produces `GameState.areas: Dictionary`, `GameState.area(id: String) -> Dictionary`, and `GameState.area_ids() -> Array[String]`.

- [ ] Add a failing campaign test asserting exact ordered IDs `shadow_crypt`, `verdant_catacombs`, `astral_foundry`, valid boss/enemy references, distinct backgrounds, and increasing threat multipliers.
- [ ] Run `campaign_test.tscn`; expect failure because `GameState.areas` is absent.
- [ ] Add complete area JSON definitions and load/validation helpers in `GameState`.
- [ ] Run the campaign test; expect zero failures.
- [ ] Commit `feat: add authored campaign area registry`.

### Task 2: Persistent unlocks and migration

**Files:**
- Modify: `src/autoload/save_system.gd`
- Modify: `tests/save_migration_test.gd`
- Modify: `tests/campaign_test.gd`

**Interfaces:**
- Produces `is_area_unlocked(id)`, `complete_area(id) -> Dictionary`, `area_wins(id)`, `best_depth(id)`, and `record_area_depth(id, depth)`.

- [ ] Add failing tests for version-3 migration, initial Shadow unlock, ordered next-area unlock, idempotent first-clear reward, win counts, and best depth.
- [ ] Run save/campaign tests; expect missing campaign API failures.
- [ ] Raise save version to 4, migrate campaign dictionaries, and implement the methods with immediate persistence.
- [ ] Re-run both tests; expect zero failures.
- [ ] Commit `feat: persist campaign unlock progression`.

### Task 3: Area-aware procedural generation and run state

**Files:**
- Modify: `src/run/run_generator.gd`
- Modify: `src/run/threat_budget.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `tests/run_generation_test.gd`
- Modify: `tests/save_migration_test.gd`

**Interfaces:**
- Changes generator to `generate(seed: int, area_id := "shadow_crypt")`.
- Changes run start to `start_new_run(selected_kit := "ember_adept", area_id := "shadow_crypt")`.
- Produces `current_area() -> Dictionary`, boundary version 3 with `area_id`, and `pending_area_id`.

- [ ] Add failing assertions across 2,000 seeds per area: configured boss, no enemy outside area pools, deterministic graph, cadence, and increasing threat scale.
- [ ] Add failing boundary round-trip tests for area ID and legacy v2 fallback to Shadow Crypt.
- [ ] Run generation/save tests; expect cross-area leakage or missing area state failures.
- [ ] Implement explicit area pool selection, boss lookup, threat multiplier, run serialization, and restoration.
- [ ] Re-run tests; expect zero failures.
- [ ] Commit `feat: generate deterministic runs per campaign area`.

### Task 4: Expedition selection and truthful navigation

**Files:**
- Create: `scenes/area_select.tscn`
- Create: `src/ui/area_select_screen.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/kit_select_screen.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Area card names use the exact prefix convention demonstrated by `AreaCard_shadow_crypt`, `AreaCard_verdant_catacombs`, and `AreaCard_astral_foundry`.
- Main-menu New Run and inactive Map open `area_select.tscn`; Continue is disabled when no active run.
- Kit selection starts `RunState.pending_area_id`.

- [ ] Add failing visual/source tests for three cards, lock/completion states, no silent run creation, and distinct `NEW EXPEDITION`/`CONTINUE RUN` behavior.
- [ ] Run `visual_test.tscn`; expect missing scene/components.
- [ ] Build a responsive premium area-select screen with background preview, boss silhouette, difficulty, first-clear reward, prerequisite, Hall return, and safe disabled state.
- [ ] Update main/kit flow and re-run visual tests.
- [ ] Commit `feat: add campaign expedition selection`.

### Task 5: Area identity assets, audio, and bosses

**Files:**
- Create: `assets/art/backgrounds/verdant_catacombs_battle.png`
- Create: `assets/art/backgrounds/astral_foundry_battle.png`
- Create: `assets/audio/verdant_ambient.wav`
- Create: `assets/audio/astral_ambient.wav`
- Modify: `data/bosses.json`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/audio_test.gd`
- Modify: `tests/boss_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- `AudioManager.set_area(area_id: String)` selects area ambient and tonal profile.
- Every configured boss uses `BossPhaseController`, not an enemy-ID special case.

- [ ] Add failing tests for loadable backgrounds/audio, three three-phase bosses, area music selection, and dynamic background source.
- [ ] Run audio/boss/visual tests; expect missing assets and hard-coded identity failures.
- [ ] Generate two clean background plates with dark central stages and no text/characters; generate two loop-safe ambient WAVs.
- [ ] Register area audio, authored Bloom Horror/Furnace Titan phases, and data-driven backgrounds/boss wiring.
- [ ] Import resources and re-run tests.
- [ ] Commit `feat: give each campaign area a distinct identity`.

### Task 6: Completion, unlock, and replay flow

**Files:**
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/gameplay_integration_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- `complete_battle` returns a result dictionary containing `area_cleared`, `first_clear`, `unlocked_area`, and `campaign_complete`.
- Boss overlay actions route to area select or Hall.

- [ ] Add failing integration tests for first clear, replay, final campaign completion, crystal banking, and active-run deactivation.
- [ ] Add failing visual tests for `AREA CLEARED`, `NEXT EXPEDITION`, and `CAMPAIGN COMPLETE` copy.
- [ ] Run tests; expect old Main Menu-only completion behavior.
- [ ] Implement result data and truthful completion overlay.
- [ ] Re-run tests and commit `feat: complete and unlock campaign expeditions`.

### Task 7: Live QA and Android delivery

**Files:**
- Create ignored artifact: `builds/PotionRogue-v9-debug.apk`

- [ ] Import all resources and run every `tests/*test.tscn`; require zero failures.
- [ ] Capture area select, Verdant map/battle, and Astral map/battle at 720×1280; inspect clipping, readability, identity, and spoiler behavior.
- [ ] Iterate only on observed regressions, then repeat targeted tests and captures.
- [ ] Export Android Debug, verify v2/v3 signatures, and record SHA-256.
- [ ] Merge to `main`, repeat the full suite, push, and clean the worktree.
