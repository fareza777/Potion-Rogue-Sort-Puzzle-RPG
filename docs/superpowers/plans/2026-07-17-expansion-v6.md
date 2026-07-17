# Potion Rogue Expansion V6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit guided tutorial, clearly audible layered music, deeply procedural runs, twenty new illustrated enemies, and a final premium GUI pass.

**Architecture:** Keep battle rules data-driven and introduce focused controllers for tutorial progression, soundtrack layering, and encounter generation. New enemy art is stored in four atlas textures with data-defined regions, while existing screens consume richer contracts without owning generation logic.

**Tech Stack:** Godot 4.7.1, GDScript, JSON content data, built-in image generation, Godot headless tests, Android export.

## Global Constraints

- Preserve the single six-bottle row.
- Keep all run output deterministic for an explicit seed.
- Keep account rewards unchanged by Assist Mode or tutorial state.
- Support 576×1280 and 720×1280 portrait layouts.
- Maintain Reduced Effects behavior.

---

### Task 1: Tutorial State Machine

**Files:**
- Create: `src/tutorial/tutorial_director.gd`
- Create: `data/tutorial_steps.json`
- Create: `tests/tutorial_test.gd`
- Create: `tests/tutorial_test.tscn`
- Modify: `src/autoload/save_system.gd`

**Interfaces:**
- Produces: `configure(replay := false)`, `accept_action(action: String) -> bool`, `current_step() -> Dictionary`, `skip()`, signals `step_changed`, `completed`, `skipped`.

- [ ] Write tests that traverse all ten actions, reject an incorrect action, persist completion, and reset for replay.
- [ ] Run `tutorial_test.tscn`; expect missing `TutorialDirector`.
- [ ] Implement a data-driven index with exact actions `intro`, `inspect_enemy`, `inspect_intent`, `select_source`, `select_target`, `undo`, `complete_potion`, `gain_mana`, `cast_skill`, `choose_path`.
- [ ] Add `tutorial_state`, `tutorial_step`, `tutorial_skipped` to save schema v3 migration without changing crystals or progression.
- [ ] Run tutorial and migration suites; commit.

### Task 2: Guided Tutorial Presentation

**Files:**
- Replace: `src/ui/tutorial.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: `TutorialDirector.current_step()` keys `title`, `body`, `action`, `target`.
- Produces: overlay nodes `TutorialDim`, `TutorialSpotlight`, `TutorialPointer`, `TutorialCard`, `TutorialSkip` and `REPLAY TUTORIAL` action.

- [ ] Add visual contract tests for every overlay node, skip, replay, and touch blocking.
- [ ] Build a clipped dim overlay with four rectangles around a live target, animated pointer, progress `N/10`, and concise instruction card.
- [ ] Forward named board/battle actions to the director and highlight the linked control only.
- [ ] Continue the last step on the map and ensure skip restores all input.
- [ ] Capture source/target/skill/map tutorial screenshots; run suites; commit.

### Task 3: Audible Layered Music

**Files:**
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/settings_screen.gd`
- Create: `tests/audio_test.gd`
- Create: `tests/audio_test.tscn`

**Interfaces:**
- Produces: `preview_music()`, `current_combat_layer() -> String`, `music_is_audible() -> bool`.

- [ ] Test default bus gain, true mute, layer identity, non-restart behavior, and preview playback.
- [ ] Add two synchronized runtime stems per layer: harmonic pulse and percussion, at audible RMS with -6 dB headroom.
- [ ] Map hall, battle, elite, and boss phases to distinct tempo/note profiles while retaining ambient WAV beds.
- [ ] Add aligned Settings preview button, active-state label, and music meter.
- [ ] Run audio and visual suites; commit.

### Task 4: Procedural Graph and Encounter Contracts

**Files:**
- Modify: `src/run/run_generator.gd`
- Modify: `src/run/threat_budget.gd`
- Modify: `data/run_rules.json`
- Modify: `src/autoload/run_state.gd`
- Modify: `tests/run_generation_test.gd`

**Interfaces:**
- `generate(seed: int) -> Dictionary` returns 12–15 nodes with `event_id` and complete encounter contracts.
- Produces: `enemy_for_tier(tier: int, rng)`, `compatible_objective(enemy, modifiers)`.

- [ ] Extend the 2,000-seed test to assert node-count range, graph determinism, cross-seed variation, boss reachability, safe route, and compatible objectives.
- [ ] Generate 1–3 nodes per middle floor, link adjacent lanes, and repair missing reachability deterministically.
- [ ] Randomize enemy, objective, modifiers, event ID, and rewards from tier-filtered pools.
- [ ] Display seed and procedural route legend on the map; persist exact graph.
- [ ] Run generation, simulation, and save suites; commit.

### Task 5: Twenty-Enemy Content Data

**Files:**
- Expand: `data/enemies.json`
- Expand: `data/intents.json`
- Modify: `tests/encounter_test.gd`
- Modify: `tests/seed_simulation_test.gd`

**Interfaces:**
- Enemy records contain `family`, `tier`, `atlas`, `atlas_region`, `motion_profile`, stats, and `intent_pool`.

- [ ] Add failing count/field tests for exactly 27 enemies and five members per new family.
- [ ] Add the twenty named enemies with onboarding-safe tier bands and intent combinations.
- [ ] Add new reusable intents `drain`, `shatter`, `weaken`, `heal`, and `double_strike` using public BattleManager operations.
- [ ] Run encounter and balance suites; commit.

### Task 6: Enemy Atlas Art and Rendering

**Files:**
- Add: `assets/art/enemies/atlas_crypt.png`
- Add: `assets/art/enemies/atlas_fungal.png`
- Add: `assets/art/enemies/atlas_arcane.png`
- Add: `assets/art/enemies/atlas_infernal.png`
- Modify: `src/ui/visual_registry.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- `VisualRegistry.enemy_texture(id: String) -> Texture2D` returns a standalone texture or `AtlasTexture` region.

- [ ] Generate four five-character, equally spaced, chroma-key atlases in the existing painterly dark-fantasy style.
- [ ] Remove chroma backgrounds with soft matte/despill and copy final PNGs into the project.
- [ ] Register atlas rectangles and construct `AtlasTexture` resources without cropping source art.
- [ ] Test every enemy texture, region bounds, motion profile, and missing-art fallback.
- [ ] Capture one battle per family; commit assets and rendering.

### Task 7: Premium GUI Pass

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/ui_kit.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Preserves existing scene paths and gameplay signals.

- [ ] Add responsive tests for 576×1280 and 720×1280, portrait thumbnails, current-route legend, enabled/disabled contrast, and tutorial safe areas.
- [ ] Rebalance typography, margins, panel ornament density, and bottom navigation.
- [ ] Add map enemy thumbnails and family accents, battle intent iconography, clearer skill readiness, and Settings status rows.
- [ ] Capture hall, two maps, tutorial, four enemy families, elite, boss, and settings; fix clipping and optical misalignment.
- [ ] Run full visual suite; commit.

### Task 8: Final Regression, APK, Merge, and Push

**Files:**
- Produce: `builds/PotionRogue-expansion-v6-debug.apk`

**Interfaces:**
- No new runtime interface.

- [ ] Run every headless suite with immediate failure propagation.
- [ ] Run 2,000 graph seeds and 1,000 modifier boards with zero failures.
- [ ] Export Android debug APK and verify v2/v3 signatures.
- [ ] Verify SHA-256, clean tracked diff, preserve user attachments, merge to `main`, rerun suites, push, and clean the owned worktree.
