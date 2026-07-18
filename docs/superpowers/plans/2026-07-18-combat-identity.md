# Combat Identity and Run Director Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make enemy encounters require distinct puzzle decisions, make seeded runs pace combat adaptively without revealing exact enemies, and make boss phases transform the board safely.

**Architecture:** Add a pure `EnemySignatureController` that converts authored signature data into validated board commands, and a pure `RunDirector` that assigns node kinds after topology creation. Existing `BattleManager`, `PuzzleBoard`, and `BossPhaseController` remain authoritative; `battle_screen.gd` wires their typed signals and presentation.

**Tech Stack:** Godot 4.3+, GDScript, JSON content definitions, headless Godot scene tests.

## Global Constraints

- Preserve version 6 saves and exact mid-battle restore.
- A seeded run remains deterministic.
- Every route contains at least three combat nodes and no consecutive non-combat nodes.
- Floors one and two use readable introductory signatures only.
- Board transformations must be solver-validated before mutation.
- Exact future enemy IDs stay hidden on the route map.
- Support 720x1280 and 576x1280 portrait layouts.
- Write and run a failing test before each production behavior change.

---

### Task 1: Pure adaptive Run Director

**Files:**
- Create: `src/run/run_director.gd`
- Modify: `src/run/run_generator.gd`
- Modify: `tests/run_generation_test.gd`

**Interfaces:**
- Consumes: `RunDirector.assign_kind(floor: int, slot: int, noncombat_slot: int, context: Dictionary, rng: RandomNumberGenerator) -> String`
- Produces: deterministic node kinds plus `risk` and `reveal_kind` metadata.

- [ ] **Step 1: Write the failing generation assertions**

Add inside the existing 2,000-seed loop:

```gdscript
assert_check(graph.has("director_version") and int(graph.director_version) == 1,
		"graph records run director version")
for node in graph.nodes:
	assert_check(node.has("reveal_kind"), "every node exposes route-safe reveal class")
	if str(node.kind) in ["battle", "elite"]:
		assert_check(str(node.reveal_kind) in ["BATTLE", "ELITE"],
				"combat reveal omits exact enemy")
```

- [ ] **Step 2: Run the focused test and verify RED**

Run `godot --headless --path . res://tests/run_generation_test.tscn`.

Expected: failures for missing `director_version` and `reveal_kind`.

- [ ] **Step 3: Implement the pure director**

Create `src/run/run_director.gd`:

```gdscript
class_name RunDirector
extends RefCounted

const VERSION := 1
const NONCOMBAT := ["event", "event", "shop", "treasure", "campfire"]

func assign_kind(floor: int, slot: int, noncombat_slot: int,
		context: Dictionary, rng: RandomNumberGenerator) -> String:
	if slot == noncombat_slot:
		var pool := NONCOMBAT.duplicate()
		if float(context.get("hp_ratio", 1.0)) <= 0.35:
			pool.append_array(["campfire", "campfire"])
		return str(pool[rng.randi_range(0, pool.size() - 1)])
	if floor >= 3 and rng.randf() < clampf(
			0.18 + float(context.get("power", 0.0)) * 0.01, 0.18, 0.30):
		return "elite"
	return "battle"

func reveal_for(kind: String) -> String:
	return {"start":"START", "battle":"BATTLE", "elite":"ELITE",
		"event":"EVENT", "shop":"SHOP", "treasure":"TREASURE",
		"campfire":"REST", "boss":"BOSS"}.get(kind, "UNCHARTED")

func risk_for(floor: int, kind: String) -> int:
	return clampi(1 + floor / 2 + (1 if kind == "elite" else 0), 1, 4)
```

Update `RunGenerator.generate()` to create one director, call `assign_kind`, add `reveal_kind` and `risk` in `_node()`, and return `"director_version": RunDirector.VERSION`.

- [ ] **Step 4: Run focused generation tests and verify GREEN**

Run the same test. Expected: all checks pass for 2,000 seeds and every authored area.

- [ ] **Step 5: Commit**

```powershell
git add src/run/run_director.gd src/run/run_generator.gd tests/run_generation_test.gd
git commit -m "feat: add deterministic adaptive run director"
```

---

### Task 2: Solver-safe board transformation API

**Files:**
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/puzzle/board_solver.gd`
- Create: `tests/board_transform_test.gd`
- Create: `tests/board_transform_test.tscn`

**Interfaces:**
- Produces: `PuzzleBoard.try_board_commands(commands: Array[Dictionary]) -> bool`
- Produces: transactional `swap_top`, `rotate_top`, and existing commands.

- [ ] **Step 1: Write a failing transactional board test**

```gdscript
var board := PuzzleBoard.new()
add_child(board)
board.generate_tutorial_board()
var before := board.export_snapshot()
check(not board.try_board_commands([{"type":"swap_top","tube":0,"other":99}]),
		"invalid transform is rejected")
check(board.export_snapshot() == before, "rejected transform is atomic")
check(board.try_board_commands([{"type":"swap_top","tube":0,"other":1}]),
		"valid transform commits")
```

- [ ] **Step 2: Run and verify RED**

Run `godot --headless --path . res://tests/board_transform_test.tscn`.

Expected: method `try_board_commands` is missing.

- [ ] **Step 3: Implement transactional commands**

Duplicate the board snapshot, apply every command, validate legal moves and `BoardSolver.has_solution(export_state(), PotionTube.CAPACITY)`, then restore the original snapshot and return `false` if any operation is invalid.

Add `swap_top` and `rotate_top` branches to `apply_board_command`. Each branch validates every index and non-empty tube before mutating. Queue redraw only after mutation succeeds.

- [ ] **Step 4: Run focused puzzle suites and verify GREEN**

Run:

```powershell
godot --headless --path . res://tests/board_transform_test.tscn
godot --headless --path . res://tests/modifier_test.tscn
godot --headless --path . res://tests/logic_test.tscn
```

Expected: all checks pass and no orphan nodes remain.

- [ ] **Step 5: Commit**

```powershell
git add src/puzzle/puzzle_board.gd src/puzzle/board_solver.gd tests/board_transform_test.gd tests/board_transform_test.tscn
git commit -m "feat: add solver-safe board transformations"
```

---

### Task 3: Data-authored enemy puzzle signatures

**Files:**
- Create: `src/battle/enemy_signature_controller.gd`
- Modify: `data/enemies.json`
- Modify: `src/ui/battle_screen.gd`
- Create: `tests/enemy_signature_test.gd`
- Create: `tests/enemy_signature_test.tscn`

**Interfaces:**
- Produces: `configure(enemy_id: String, enemy: Dictionary, seed: int) -> void`
- Produces: `on_player_move(board: PuzzleBoard) -> Dictionary`
- Produces: `snapshot() -> Dictionary` and `restore(data: Dictionary) -> bool`
- Emits: `signature_triggered(payload: Dictionary)`.

- [ ] **Step 1: Write failing signature tests**

Test deterministic cadence, intro allow-list, snapshot parity, and harmless fallback:

```gdscript
var signature := EnemySignatureController.new()
signature.configure("slime", {"signature":{"id":"mark","every_moves":3}}, 77)
check(signature.preview().id == "mark", "signature is visible before trigger")
signature.on_player_move(null)
signature.on_player_move(null)
var saved := signature.snapshot()
var restored := EnemySignatureController.new()
restored.configure("slime", {"signature":{"id":"mark","every_moves":3}}, 77)
check(restored.restore(saved), "signature snapshot restores")
check(restored.snapshot() == saved, "signature restore is exact")
```

- [ ] **Step 2: Run and verify RED**

Run `godot --headless --path . res://tests/enemy_signature_test.tscn`.

Expected: `EnemySignatureController` cannot be resolved.

- [ ] **Step 3: Implement bounded signatures**

The controller stores ID, cadence, move count, marked tube, and RNG state. It uses `board.try_board_commands()` for Seal and Shift. Mark, Hunt, and Siphon return battle payloads without direct UI changes. Unknown IDs return `{"triggered":false, "fallback":"attack"}`.

Author signatures by tier:

- Tier 1: Slime=Mark, Skeleton=Seal, Bone Rat=Hunt, Grave Archer=Mark, Sporeling=Mark, Rune Wisp=Seal.
- Tier 2: Poison Beast=Corrupt, Wailing Spirit=Siphon, Myconid Brute=Hunt, Rotcap Shaman=Corrupt, Mossback Toad=Split, Mimic Flask=Shift, Clockwork Imp=Hunt, Cinder Hound=Hunt, Ash Harpy=Mark.
- Tier 3+: Ward, Shift, Corrupt, or stronger family-matched cadence.

Wire `board.move_made` to the controller in `battle_screen.gd`, expose its label beside the intent HUD, and persist it in encounter capture/restore.

- [ ] **Step 4: Run focused combat and snapshot tests**

Run:

```powershell
godot --headless --path . res://tests/enemy_signature_test.tscn
godot --headless --path . res://tests/combat_overhaul_test.tscn
godot --headless --path . res://tests/encounter_snapshot_test.tscn
```

Expected: all pass; malformed signatures never mutate the board.

- [ ] **Step 5: Commit**

```powershell
git add src/battle/enemy_signature_controller.gd data/enemies.json src/ui/battle_screen.gd tests/enemy_signature_test.gd tests/enemy_signature_test.tscn
git commit -m "feat: give enemies distinct puzzle signatures"
```

---

### Task 4: Boss board phases and exact restore

**Files:**
- Modify: `data/bosses.json`
- Modify: `src/battle/boss_phase_controller.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/boss_test.gd`
- Modify: `tests/encounter_snapshot_test.gd`

**Interfaces:**
- Extends phase config with `board_action: String`.
- Produces: `BossPhaseController.pending_board_action() -> String`.
- Snapshot includes `applied_phase_actions: Array[int]`.

- [ ] **Step 1: Add failing boss transformation assertions**

Assert every boss has three phases, at least one advanced phase has a board action, repeated HP updates never reapply it, and restored controllers retain applied phases.

- [ ] **Step 2: Run and verify RED**

Run `godot --headless --path . res://tests/boss_test.tscn`.

Expected: missing `pending_board_action` and snapshot fields.

- [ ] **Step 3: Implement phase action queue**

On `_enter_phase`, enqueue the phase's action only once. `pending_board_action()` returns and clears it. Snapshot and restore applied phase indices. In `battle_screen.gd`, pause board input, choose valid deterministic tube indices, apply a transactional command, play the transition, show the phase description, and re-enable input. Rejected transformations leave the board unchanged.

Author Fire Golem=`heat_seal`, Bloom Horror=`spore_corrupt`, and Furnace Titan=`gravity_shift`.

- [ ] **Step 4: Verify boss and resume behavior**

Run:

```powershell
godot --headless --path . res://tests/boss_test.tscn
godot --headless --path . res://tests/encounter_snapshot_test.tscn
godot --headless --path . res://tests/gameplay_integration_test.tscn
```

Expected: phase actions apply once and exact restore remains equal.

- [ ] **Step 5: Commit**

```powershell
git add data/bosses.json src/battle/boss_phase_controller.gd src/ui/battle_screen.gd tests/boss_test.gd tests/encounter_snapshot_test.gd
git commit -m "feat: add solver-safe boss board phases"
```

---

### Task 5: Route secrecy and milestone verification

**Files:**
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `tests/action_clarity_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: node `reveal_kind` and `risk`.
- Produces: route cards that never render unvisited enemy names or sprites.

- [ ] **Step 1: Add failing route secrecy assertions**

Assert unvisited nodes render only reveal class and risk, the current node may reveal encounter details, and map copy explains the risk scale.

- [ ] **Step 2: Run and verify RED**

Run action clarity and visual tests. Expected: route cards omit risk or still reference unvisited enemy details.

- [ ] **Step 3: Update route presentation**

Render `reveal_kind`, one-to-four threat pips, and a family-neutral icon. Only visited/current nodes may use encounter names. Update legend copy to `PATHS HIDE THEIR GUARDIAN • MORE FLAMES MEAN MORE RISK`. Retain Back to Hall and its saved-run tooltip.

- [ ] **Step 4: Run the complete regression matrix**

Execute every `tests/*_test.tscn` using the existing suite runner. Expected: all suites pass without warnings and all seed simulations remain deterministic.

- [ ] **Step 5: Capture and release-check**

Capture Hall, map, first battle, signature trigger, boss phase, and pause at both supported portrait profiles. Inspect clipping, overlap, labels, and touch targets. Export a debug APK and run `tools/validate_release.ps1`.

- [ ] **Step 6: Commit**

```powershell
git add src/ui/dungeon_route.gd src/ui/map_screen.gd tests/action_clarity_test.gd tests/visual_test.gd
git commit -m "feat: finish combat identity milestone"
```

