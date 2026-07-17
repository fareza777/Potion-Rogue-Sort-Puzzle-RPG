# Potion Rogue Gameplay Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengubah loop battle linear menjadi roguelike 12–18 menit dengan objective dan modifier puzzle, enemy intent, mana/skill/ultimate, combo, build, peta bercabang, event, dan boss multi-phase.

**Architecture:** Gameplay tetap dipisahkan menjadi pure logic dan presentation. `BattleManager` tetap memiliki damage state dan `PuzzleBoard` tetap memiliki tabung/legal pour; controller baru menerima `EncounterContract`, bereaksi melalui signal, dan tidak mengakses internal system lain secara langsung. Seluruh generation memakai seed, validation, batas percobaan, dan fallback deterministik.

**Tech Stack:** Godot 4.7.1, GDScript typed, JSON content data, signal-driven UI, headless scene tests, Android export preset `Android Debug`.

## Global Constraints

- Satu run ditargetkan 12–18 menit; battle reguler 60–100 detik.
- Minimal 60% reward mengubah aturan atau sinergi, bukan hanya angka.
- Battle 1–2 hanya memakai mekanik pengantar dan board tutorial-safe.
- Boss tidak menerima modifier acak.
- Modifier tidak boleh menghasilkan board tanpa legal move.
- Save lama harus dimigrasikan secara idempotent; active run invalid diberi crystal compensation.
- Reduced Effects tidak boleh mengubah state atau timing logic.
- Semua layar harus terbaca pada 576×1280 dan 720×1280.
- Setiap task berakhir dengan build playable, tes hijau, dan commit terpisah.

## File and Responsibility Map

- `src/run/encounter_contract.gd`: immutable validated encounter description.
- `src/run/run_generator.gd`: seeded branching graph generation.
- `src/run/reward_generator.gd`: compatible mutation/relic/catalyst choices.
- `src/run/threat_budget.gd`: difficulty composition by floor and node kind.
- `src/battle/objective_controller.gd`: objective progress and victory condition.
- `src/battle/enemy_intent_controller.gd`: previewable enemy action selection.
- `src/battle/combo_resolver.gd`: potion history and combo output.
- `src/battle/skill_controller.gd`: mana, active skill, cooldown, ultimate.
- `src/battle/boss_phase_controller.gd`: deterministic boss phase state machine.
- `src/puzzle/modifier_controller.gd`: modifier lifecycle and board-facing commands.
- `src/puzzle/board_solver.gd`: legal-move and bounded solvability checks.
- `src/autoload/run_state.gd`: persisted run graph, kit, build, and current node.
- `src/autoload/save_system.gd`: save schema migration.
- `src/ui/battle_screen.gd`: objective/intent/mana/combo presentation only.
- `src/ui/map_screen.gd` and `src/ui/dungeon_route.gd`: branching map interaction.
- `data/*.json`: validated content definitions.
- `tests/*_test.gd`: pure logic, seeded property, integration, and visual contracts.

---

### Task 1: Versioned Encounter Contract and Content Validation

**Files:**
- Create: `src/run/encounter_contract.gd`
- Create: `data/objectives.json`
- Create: `data/modifiers.json`
- Modify: `src/autoload/game_state.gd`
- Create: `tests/encounter_test.gd`
- Create: `tests/encounter_test.tscn`

**Interfaces:**
- Produces: `EncounterContract.from_dict(raw: Dictionary) -> EncounterContract`
- Produces: `EncounterContract.is_valid() -> bool`
- Produces: fields `seed`, `enemy_id`, `objective_id`, `modifier_ids`, `reward_mult`, `node_kind`

- [ ] **Step 1: Add a failing contract test**

```gdscript
var valid := EncounterContract.from_dict({
    "seed": 42, "enemy": "slime", "objective": "defeat",
    "modifiers": ["hidden_layer"], "reward_mult": 1.0, "kind": "battle",
})
check(valid.is_valid(), "valid encounter contract")
var fallback := EncounterContract.from_dict({"enemy": "missing"})
check(fallback.enemy_id == "slime", "invalid contract uses slime fallback")
```

- [ ] **Step 2: Run the test and verify the missing class failure**

Run: `Godot_v4.7.1-stable_win64.exe --headless --path . res://tests/encounter_test.tscn`

Expected: non-zero exit with `EncounterContract` not declared.

- [ ] **Step 3: Implement the typed contract and exact fallback**

```gdscript
class_name EncounterContract
extends RefCounted

var seed := 0
var enemy_id := "slime"
var objective_id := "defeat"
var modifier_ids: Array[String] = []
var reward_mult := 1.0
var node_kind := "battle"

static func from_dict(raw: Dictionary) -> EncounterContract:
    var result := EncounterContract.new()
    result.seed = int(raw.get("seed", 0))
    result.enemy_id = str(raw.get("enemy", "slime"))
    if not GameState.enemies.has(result.enemy_id): result.enemy_id = "slime"
    result.objective_id = str(raw.get("objective", "defeat"))
    if not GameState.objectives.has(result.objective_id): result.objective_id = "defeat"
    result.modifier_ids.assign(raw.get("modifiers", []))
    result.modifier_ids = result.modifier_ids.filter(
        func(id: String) -> bool: return GameState.modifiers.has(id))
    result.reward_mult = clampf(float(raw.get("reward_mult", 1.0)), 0.5, 3.0)
    result.node_kind = str(raw.get("kind", "battle"))
    return result

func is_valid() -> bool:
    return GameState.enemies.has(enemy_id) and GameState.objectives.has(objective_id)
```

- [ ] **Step 4: Add objective/modifier registries to `GameState` and run all tests**

Load both JSON files through the existing `load_data_file` fallback path. Run logic, visual, and encounter tests; expected: all exit 0.

- [ ] **Step 5: Commit**

```powershell
git add src/run/encounter_contract.gd data/objectives.json data/modifiers.json src/autoload/game_state.gd tests/encounter_test.*
git commit -m "feat: add validated encounter contracts"
```

### Task 2: Objective Controller

**Files:**
- Create: `src/battle/objective_controller.gd`
- Modify: `data/objectives.json`
- Modify: `tests/encounter_test.gd`

**Interfaces:**
- Consumes: `EncounterContract.objective_id`
- Produces: signals `progress_changed(current: int, target: int)`, `completed`
- Produces: `configure(id: String, config: Dictionary)`, `on_enemy_defeated()`, `on_enemy_attacked()`, `on_potion_completed(color: String)`, `on_armor_damaged(amount: int)`, `on_curse_cleansed(count: int)`

- [ ] **Step 1: Write failing tests for all five objectives**

Test defeat=enemy defeated, survive=three attacks, brew order=`red,blue,purple`, armor break=20 armor, cleanse=three layers. Assert completion occurs exactly once.

- [ ] **Step 2: Run `encounter_test.tscn`; expect missing `ObjectiveController`**

- [ ] **Step 3: Implement an event-fed controller**

Store `current`, `target`, `sequence_index`, and `_completed`. Every public event calls `_advance(amount)` only when relevant. `_finish()` must guard `_completed` before emitting.

- [ ] **Step 4: Populate exact configs**

```json
{
  "defeat": {"label":"Defeat the enemy","event":"enemy_defeated","target":1},
  "survive": {"label":"Survive 3 attacks","event":"enemy_attacked","target":3},
  "brew_order": {"label":"Brew the shown sequence","event":"potion_completed","sequence":["red","blue","purple"]},
  "armor_break": {"label":"Break 20 armor","event":"armor_damaged","target":20},
  "cleanse": {"label":"Cleanse 3 cursed layers","event":"curse_cleansed","target":3}
}
```

- [ ] **Step 5: Run tests and commit**

Expected: objective tests and existing 33 logic checks pass.

### Task 3: Previewable Enemy Intent

**Files:**
- Create: `src/battle/enemy_intent_controller.gd`
- Create: `data/intents.json`
- Modify: `data/enemies.json`
- Modify: `src/battle/battle_manager.gd`
- Modify: `tests/logic_test.gd`

**Interfaces:**
- Produces: `preview() -> Dictionary` containing `id`, `label`, `damage_min`, `damage_max`, `icon`, `moves`
- Produces: `resolve(battle: BattleManager, board: PuzzleBoard) -> void`
- `BattleManager` produces `armor_changed(delta: int)` and `enemy_action_resolved(intent_id: String)`

- [ ] **Step 1: Add failing deterministic preview/resolution tests**

Seed the controller, preview an attack, resolve it, and assert actual pre-shield damage lies in the preview range. Test lock, armor, poison, corruption, and enrage IDs.

- [ ] **Step 2: Implement weighted seeded selection**

Use a local `RandomNumberGenerator`, never global `randf()`. Choose from each enemy's `intent_pool`; keep `current_intent` unchanged until resolved.

- [ ] **Step 3: Route the existing basic attack and post-attack abilities through intents**

Keep existing damage methods in `BattleManager`; intent controller calls public methods such as `resolve_enemy_attack(multiplier: float)` and emits the resolved ID.

- [ ] **Step 4: Verify prediction parity and commit**

Run logic test twice with the same seed; expected identical intent order and 0 failures.

### Task 4: Board Solver and Modifier Boundary

**Files:**
- Create: `src/puzzle/board_solver.gd`
- Create: `src/puzzle/modifier_controller.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Create: `tests/modifier_test.gd`
- Create: `tests/modifier_test.tscn`

**Interfaces:**
- `PuzzleBoard.export_state() -> Array[Array]`
- `PuzzleBoard.import_state(state: Array[Array]) -> void`
- `PuzzleBoard.legal_moves() -> Array[Vector2i]`
- `PuzzleBoard.apply_board_command(command: Dictionary) -> bool`
- `BoardSolver.has_solution(state: Array[Array], capacity: int, max_states := 50000) -> bool`
- `ModifierController.configure(ids: Array[String], seed: int, board: PuzzleBoard) -> bool`

- [ ] **Step 1: Write tests for snapshot round-trip, legal moves, and bounded solver**

Use the tutorial board as solvable and a full mismatched two-color board with no empty tube as unsolvable.

- [ ] **Step 2: Implement board export/import and legal move enumeration**

Return copied arrays; never expose `PotionTube.contents` by reference.

- [ ] **Step 3: Implement BFS solver with canonical state keys**

Stop at `max_states`; return false on exhaustion. Skip moves that only reverse the immediately previous state.

- [ ] **Step 4: Implement command-only modifier boundary**

Accepted commands: `lock_tube`, `unlock_tube`, `replace_top`, `append_layer`, `reveal_top`, `set_capacity`. Reject invalid tube indices and commands that exceed capacity.

- [ ] **Step 5: Run modifier and existing tests; commit**

### Task 5: Eight Puzzle Modifiers and Safe Generation

**Files:**
- Modify: `src/puzzle/modifier_controller.gd`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `data/modifiers.json`
- Modify: `tests/modifier_test.gd`

**Interfaces:**
- Produces modifier hooks `before_move`, `after_move`, `after_enemy_action`, `on_potion_completed`
- Produces signals `curse_cleansed(count: int)`, `volatile_expired(tube_index: int)`, `board_changed`

- [ ] **Step 1: Add one failing behavioral test per modifier**

Cover `frozen_tube`, `cursed_layer`, `volatile_liquid`, `hidden_layer`, `wild_essence`, `chain_lock`, `corruption`, and `unstable_flask`.

- [ ] **Step 2: Implement modifier state as metadata, not encoded color strings**

Add a typed dictionary per tube/layer keyed by stable layer IDs. Wild Essence matching is handled in `can_receive(color)`; hidden rendering never changes the underlying color.

- [ ] **Step 3: Add compatibility rules and generation retry**

Disallow frozen+chain on the same initial tube, corruption+full-capacity boards, and unstable capacity below current contents. Try 30 seeded layouts, then use a validated preset.

- [ ] **Step 4: Run 1,000-seed property test**

Expected: every accepted board has at least one legal move, every generation finishes, and the fallback counter remains visible in test output.

- [ ] **Step 5: Commit**

### Task 6: Combo Resolver

**Files:**
- Create: `src/battle/combo_resolver.gd`
- Create: `data/combos.json`
- Create: `tests/combat_depth_test.gd`
- Create: `tests/combat_depth_test.tscn`

**Interfaces:**
- Produces: signal `combo_resolved(combo_id: String, payload: Dictionary)`
- Produces: `push_potion(color: String) -> Dictionary`, `history() -> Array[String]`, `ultimate_charge() -> int`

- [ ] **Step 1: Test all eight two-color and three ultimate patterns**

Assert longest match wins, history is limited to three, and no match still advances history.

- [ ] **Step 2: Implement suffix matching from JSON**

Sort patterns by descending length at load. Return `{}` when none match. Never apply damage inside the resolver.

- [ ] **Step 3: Add payloads for burst, barrier, reflect, detonation, burning venom, fortify, regeneration, and venom ward**

- [ ] **Step 4: Run combat-depth test and commit**

### Task 7: Mana, Active Skills, and Ultimates

**Files:**
- Create: `src/battle/skill_controller.gd`
- Create: `data/kits.json`
- Create: `src/ui/kit_select_screen.gd`
- Create: `scenes/kit_select.tscn`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `tests/combat_depth_test.gd`

**Interfaces:**
- Produces: `configure(kit_id: String)`, `gain_mana(amount: int)`, `can_cast(skill_id: String) -> bool`, `cast(skill_id: String, target: Dictionary) -> Dictionary`
- Produces signals `mana_changed(current: int, maximum: int)`, `skill_cast`, `ultimate_ready`

- [ ] **Step 1: Test mana cap, cost, invalid target, cooldown, and ultimate charge**

- [ ] **Step 2: Implement the three kits**

`ember_adept/flash_boil`, `verdant_warden/purify`, and `void_brewer/transmute`; each kit defines passive, active cost, and ultimate pattern.

- [ ] **Step 3: Add starting-kit selection before a new run**

`NEW RUN` opens `kit_select.tscn`. The screen presents all three kits with passive, active skill, and ultimate summary. Confirm calls `RunState.start_new_run(kit_id)`; back returns to hall without mutating the active run.

- [ ] **Step 4: Implement board-safe skills via `apply_board_command`**

No skill mutates tube contents directly. Invalid cast returns `{"ok": false, "reason": "invalid_target"}` without spending mana.

- [ ] **Step 5: Add exact mana rule**

Base completion grants 25 mana; completing a potion containing Wild Essence grants 18; optional objective grants 15. Clamp to 100.

- [ ] **Step 6: Test and commit**

### Task 8: Mutations, Relics, Catalysts, and Reward Generator

**Files:**
- Create: `src/run/reward_generator.gd`
- Create: `data/mutations.json`
- Expand: `data/relics.json`
- Create: `data/catalysts.json`
- Expand: `data/upgrades.json`
- Modify: `src/autoload/run_state.gd`
- Modify: `tests/combat_depth_test.gd`

**Interfaces:**
- `RunState.mutation_ids`, `RunState.relic_ids`, `RunState.catalyst_ids`
- `RewardGenerator.choices(kind: String, count: int, seed: int, build: Dictionary) -> Array[String]`

- [ ] **Step 1: Test stacking order and three unique choices**

Apply base potion → mutation → relic → catalyst → temporary combo modifier. Assert deterministic results and no duplicate choices.

- [ ] **Step 2: Implement 24 mutations, 18 relics, 12 catalysts, and 10 supporting stat upgrades in data**

Use effect operations `add`, `multiply`, `replace`, `on_complete`, `on_absorb`, `on_kill`; reject unknown operations during load.

- [ ] **Step 3: Implement compatibility-biased reward weighting**

Compatible choices get weight 3, neutral weight 1, owned non-repeatable weight 0. Ensure at least one neutral option when available.

- [ ] **Step 4: Run content count, stacking, and uniqueness tests; commit**

### Task 9: Threat Budget and Branching Run Graph

**Files:**
- Create: `src/run/threat_budget.gd`
- Create: `src/run/run_generator.gd`
- Create: `data/run_rules.json`
- Modify: `src/autoload/run_state.gd`
- Create: `tests/run_generation_test.gd`
- Create: `tests/run_generation_test.tscn`

**Interfaces:**
- `RunGenerator.generate(seed: int) -> Dictionary`
- Graph node shape: `{id, floor, lane, kind, links, contract, visited}`
- `ThreatBudget.for_node(floor: int, kind: String) -> Dictionary`

- [ ] **Step 1: Test graph invariants across 1,000 seeds**

Every graph has 10–12 reachable nodes, one boss, no consecutive elite on a path, at least one safe route, and two choices on the majority of non-terminal floors.

- [ ] **Step 2: Implement lane-based graph generation**

Use three lanes and seven logical floors. Generate links first, verify reachability, then assign node kinds using seeded weights.

- [ ] **Step 3: Implement threat tiers**

Floors 1–2 allow only introduction modifiers; battle allows one modifier; elite allows two compatible modifiers; boss allows none.

- [ ] **Step 4: Serialize graph and current node in `RunState`; test round-trip; commit**

### Task 10: Events, Treasure, Shop, and Campfire Logic

**Files:**
- Create: `src/run/event_resolver.gd`
- Create: `data/events.json`
- Create: `src/ui/event_screen.gd`
- Create: `scenes/event.tscn`
- Modify: `src/ui/shop_screen.gd`
- Modify: `tests/run_generation_test.gd`

**Interfaces:**
- `EventResolver.preview(event_id: String, choice_id: String) -> Dictionary`
- `EventResolver.apply(event_id: String, choice_id: String, run: RunState) -> Dictionary`
- RunState operations: `heal`, `spend_run_crystals`, `add_relic`, `remove_relic`, `add_mutation`, `cleanse_curse`

- [ ] **Step 1: Test six events with explicit preview parity**

The guaranteed result in preview must equal the guaranteed result applied. Random bonus uses the run seed and is returned separately.

- [ ] **Step 2: Implement event operations and validation**

Reject unaffordable choices without mutating state. Persist `resolved_event_ids` to prevent duplicate rewards on reload.

- [ ] **Step 3: Add shop inventory of three items, one service, one paid reroll**

- [ ] **Step 4: Add treasure resolution**

Treasure offers one catalyst and run crystals. A cursed chest explicitly previews its curse and gives a stronger relic; declining it grants only the crystals. Mark the node resolved before changing scenes so reload cannot duplicate rewards.

- [ ] **Step 5: Add campfire one-choice rule: heal 30%, empower one potion, or cleanse one curse**

- [ ] **Step 6: Run tests and commit**

### Task 11: Branching Map UI

**Files:**
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/ui/visual_registry.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes `RunState.run_graph` and `RunState.current_node_id`
- Produces `node_selected(node_id: String)` only for linked reachable nodes

- [ ] **Step 1: Add visual contract tests for three lanes, node legends, reachability state, and route links**

- [ ] **Step 2: Render graph nodes from data**

Use fixed normalized lane coordinates and floor spacing. Cleared, current, reachable, and locked states must differ by shape/icon as well as color.

- [ ] **Step 3: Route selected kinds to battle, event, shop, treasure reward, campfire, or boss**

- [ ] **Step 4: Capture 576×1280 and 720×1280 map previews, verify safe areas, run visual tests, commit**

### Task 12: Battle Integration and Tactical HUD

**Files:**
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `tests/visual_test.gd`
- Create: `tests/gameplay_integration_test.gd`
- Create: `tests/gameplay_integration_test.tscn`

**Interfaces:**
- Consumes contract, objective, modifier, intent, combo, and skill controllers
- HUD nodes: `ObjectivePanel`, `EnemyIntent`, `ManaMeter`, `ComboSlots`, `SkillButton`, `UltimateButton`

- [ ] **Step 1: Write an integration test for one full defeat encounter**

Load a deterministic contract, complete potion sequences, resolve intent, cast a skill, win, and assert one reward transition.

- [ ] **Step 2: Instantiate controllers in battle screen and wire signals once**

Battle screen creates controllers after `RunState.current_contract()` and before board generation. Disable puzzle input during resolution and re-enable it from a single completion callback.

- [ ] **Step 3: Add compact tactical HUD**

Intent and objective live above the turn banner; mana/skill/ultimate live above bottom controls; combo slots occupy one horizontal strip. Preserve the six-bottle single row.

- [ ] **Step 4: Add tooltip/long-press explanations and Reduced Effects presentation paths**

- [ ] **Step 5: Capture battle previews, run all tests, commit**

### Task 13: Fire Golem Three-Phase Boss

**Files:**
- Create: `src/battle/boss_phase_controller.gd`
- Create: `data/bosses.json`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/ui/enemy_display.gd`
- Modify: `src/ui/battle_screen.gd`
- Create: `tests/boss_test.gd`
- Create: `tests/boss_test.tscn`

**Interfaces:**
- Produces `phase_changed(index: int, config: Dictionary)` exactly once per threshold
- Phases: `armored_core`, `molten_floor`, `inferno`

- [ ] **Step 1: Test 70% and 40% thresholds, single emission, and reload state**

- [ ] **Step 2: Implement phase state machine independent of animation**

Phase state changes synchronously; presentation receives the signal. Phase 1 uses armor break, phase 2 adds volatile liquid, phase 3 shortens attack interval and exposes ultimate window.

- [ ] **Step 3: Add 1.8-second maximum phase presentation**

Pause input, play banner/animation/audio layer, then resume without decrementing move counter.

- [ ] **Step 4: Test skip/reduced-effects paths and commit**

### Task 14: Save Migration, Resume, and Assist Mode

**Files:**
- Modify: `src/autoload/save_system.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/settings_screen.gd`
- Create: `tests/save_migration_test.gd`
- Create: `tests/save_migration_test.tscn`

**Interfaces:**
- Save schema version increments from current value to `2`
- `SaveSystem.migrate(data: Dictionary) -> Dictionary`
- `RunState.resume_from_save(data: Dictionary) -> bool`

- [ ] **Step 1: Add fixtures for legacy profile, legacy active run, v2 run, and corrupt content IDs**

- [ ] **Step 2: Implement idempotent migration**

Legacy profile retains crystals/permanent upgrades. Legacy active run becomes inactive and grants exactly 10 compensation crystals once, recorded by `legacy_run_compensated: true`.

- [ ] **Step 3: Persist graph, node, kit, build, mana-independent battle boundary, and event resolution IDs**

Resume only at map/reward boundaries; mid-pour state is not persisted.

- [ ] **Step 4: Add Assist Mode setting**

Assist adds one enemy-delay move and legal-move highlight. It never changes rewards or content unlocks.

- [ ] **Step 5: Offer Assist Mode after two consecutive defeats on floors 1–2**

Persist `early_defeat_streak`; reset it on victory or when leaving floor 2. The defeat overlay offers `ENABLE ASSIST` and `KEEP STANDARD`. Either choice continues normally and never changes reward tables.

- [ ] **Step 6: Run migration twice per fixture, assert identical output, commit**

### Task 15: Spectacle, Audio Layers, and Accessibility

**Files:**
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/enemy_display.gd`
- Modify: `src/autoload/audio_manager.gd`
- Add: `assets/audio/` battle/elite/boss layers and cues
- Modify: `tests/visual_test.gd`

**Interfaces:**
- `AudioManager.set_combat_layer(layer: String)` with `explore`, `battle`, `elite`, `boss_phase_1..3`
- `BattleFx.play_combo(level: int, color: Color)`, `play_ultimate(id: String)`, `play_phase_transition(id: String)`

- [ ] **Step 1: Add interface and asset-existence tests**

- [ ] **Step 2: Implement potion-specific projectiles, controlled hit pause, damage numbers, defeat dissolve, and ultimate finisher**

- [ ] **Step 3: Implement layered crossfades without restarting the base track**

- [ ] **Step 4: Verify Reduced Effects removes large shake, rapid flash, and dense particles while signals finish at the same frame boundary**

- [ ] **Step 5: Capture normal/reduced previews, run tests, commit**

### Task 16: Content Completion and Balance Simulation

**Files:**
- Expand: `data/enemies.json`, `data/intents.json`, `data/events.json`, `data/run_rules.json`
- Create: `tests/seed_simulation_test.gd`
- Create: `tests/seed_simulation_test.tscn`
- Modify: `tests/logic_test.gd`

**Interfaces:**
- Simulation produces aggregate JSON: win proxy, average legal moves, modifier frequency, reward archetype coverage, fallback count

- [ ] **Step 1: Add content-count tests**

Assert 3 kits, 5 objectives, 8 modifiers, 24 mutations, 18 relics, 12 catalysts, 10 supporting upgrades, 6 events, and one three-phase boss.

- [ ] **Step 2: Run 1,000 graph seeds and 1,000 board seeds**

Fail on unreachable boss, illegal modifier pair, zero legal move, generation timeout, duplicate reward trio, or missing fallback metadata.

- [ ] **Step 3: Apply initial balance bands**

Battle 1 enemy attack every 4–5 moves and damage ≤10% base max HP; regular battle expected incoming damage ≤35% max HP; elite ≤55%; boss phase attack preview always leaves a defensive counterplay unless player is already below 10% HP.

- [ ] **Step 4: Run three deterministic full-run integration fixtures, one per kit**

- [ ] **Step 5: Commit data and simulation tests**

### Task 17: Final Regression, Device QA, APK, Merge, and Push

**Files:**
- Modify only files required by discovered regressions
- Produce: `builds/PotionRogue-gameplay-v5-debug.apk`

**Interfaces:**
- No new gameplay interface; this task verifies all prior contracts.

- [ ] **Step 1: Run every headless suite sequentially**

```powershell
& $godot --headless --path . res://tests/logic_test.tscn
& $godot --headless --path . res://tests/encounter_test.tscn
& $godot --headless --path . res://tests/modifier_test.tscn
& $godot --headless --path . res://tests/combat_depth_test.tscn
& $godot --headless --path . res://tests/run_generation_test.tscn
& $godot --headless --path . res://tests/gameplay_integration_test.tscn
& $godot --headless --path . res://tests/boss_test.tscn
& $godot --headless --path . res://tests/save_migration_test.tscn
& $godot --headless --path . res://tests/seed_simulation_test.tscn
& $godot --headless --path . res://tests/visual_test.tscn
```

Expected: every suite exits 0 with zero failures.

- [ ] **Step 2: Capture and inspect all primary screens at both target resolutions**

Screens: hall, branching map, normal battle, modifier battle, skill-ready battle, reward, event, shop, campfire, boss phases 1–3, settings. Reject clipping, overlap, tiny labels, missing intent, or bottles leaving one row.

- [ ] **Step 3: Export and validate Android APK**

```powershell
$env:ANDROID_HOME='C:\Android\Sdk'
& $godot --headless --path . --export-debug 'Android Debug' 'builds/PotionRogue-gameplay-v5-debug.apk'
& 'C:\Android\Sdk\build-tools\34.0.0\apksigner.bat' verify --verbose 'builds/PotionRogue-gameplay-v5-debug.apk'
```

Expected: export done; APK verifies with v2 and v3 signing.

- [ ] **Step 4: Verify git diff, commit regression fixes, merge to `main`, rerun tests, and push**

Do not remove an owned worktree until merge and post-merge verification both succeed.
