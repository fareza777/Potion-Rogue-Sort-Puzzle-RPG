# Engine Integrity and Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee recoverable potion boards, bounded New Mix latency, deterministic replay diagnostics, and mobile layout coverage.

**Architecture:** Keep `PuzzleBoard` as the only live-board mutation boundary. Add pure inspection and journal classes, then let the battle scene coordinate asynchronous remix jobs and checkpoints through narrow APIs.

**Tech Stack:** Godot 4.7.1, GDScript, WorkerThreadPool, existing headless scene tests.

## Global Constraints

- Add no third-party runtime dependency.
- Existing version 1.3.0 saves must load without campaign or active-run loss.
- Emergency recovery always costs one move and never requires mana.
- Potion layers remain color-only.
- Any failed or stale remix result charges no resource and cannot overwrite a newer board.

---

### Task 1: Board integrity decision boundary

**Files:**
- Create: `src/puzzle/board_integrity_guard.gd`
- Modify: `src/puzzle/puzzle_board.gd:82-160,227-245`
- Test: `tests/board_integrity_guard_test.gd`
- Test: `tests/board_integrity_guard_test.tscn`

**Interfaces:**
- Consumes: `BoardSolver.analyze(state, max_states, capacity)` and a `PuzzleBoard.export_snapshot()` dictionary.
- Produces: `BoardIntegrityGuard.inspect(snapshot: Dictionary) -> Dictionary` with `status`, `reason`, and `analysis`; `PuzzleBoard.integrity_report() -> Dictionary`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends Node

var failures := 0

func _ready() -> void:
	var guard := BoardIntegrityGuard.new()
	_assert(guard.inspect({"version":1,"state":[["red"],["green"],[],[],[],[]],
			"capacities":[4,4,4,4,4,4]}).status == "recoverable", "partial colors recover")
	_assert(guard.inspect({"version":1,"state":"bad"}).status == "invalid", "malformed rejects")
	var valid := BoardFactory.generate(91, "standard")
	_assert(guard.inspect({"version":1,"state":valid.state,
			"capacities":[4,4,4,4,4,4]}).status == "valid", "verified board passes")
	print("---\n3 checks, %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _assert(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS  " if ok else "FAIL  ", label)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/board_integrity_guard_test.tscn
```

Expected: parser failure because `BoardIntegrityGuard` does not exist.

- [ ] **Step 3: Implement the pure guard and board route**

```gdscript
class_name BoardIntegrityGuard
extends RefCounted

func inspect(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("version", 0)) != 1 or typeof(snapshot.get("state")) != TYPE_ARRAY:
		return {"status":"invalid", "reason":"malformed", "analysis":{}}
	var state: Array = snapshot.state
	var capacities: Array = snapshot.get("capacities", [])
	if state.is_empty() or capacities.size() != state.size():
		return {"status":"invalid", "reason":"shape", "analysis":{}}
	var counts := {}
	var capacity := 4
	for index in state.size():
		capacity = maxi(int(capacities[index]), 1)
		if typeof(state[index]) != TYPE_ARRAY or state[index].size() > capacity:
			return {"status":"invalid", "reason":"capacity", "analysis":{}}
		for value in state[index]:
			var color := str(value)
			if color.is_empty(): return {"status":"invalid", "reason":"color", "analysis":{}}
			counts[color] = int(counts.get(color, 0)) + 1
	for color in counts:
		if int(counts[color]) % capacity != 0:
			return {"status":"recoverable", "reason":"incomplete_color_set", "analysis":{}}
	var analysis := BoardSolver.analyze(state, 50000, capacity)
	if not bool(analysis.solvable):
		return {"status":"recoverable", "reason":"unsolvable", "analysis":analysis}
	return {"status":"valid", "reason":"", "analysis":analysis}
```

Add to `PuzzleBoard`:

```gdscript
func integrity_report() -> Dictionary:
	return BoardIntegrityGuard.new().inspect(export_snapshot())
```

- [ ] **Step 4: Run focused and existing board tests**

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/board_integrity_guard_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/board_transform_test.tscn
```

Expected: both scenes report zero failures.

- [ ] **Step 5: Commit**

```powershell
git add src/puzzle/board_integrity_guard.gd src/puzzle/puzzle_board.gd tests/board_integrity_guard_test.*
git commit -m "engine: guard potion board integrity"
```

### Task 2: Generation-safe remix job controller

**Files:**
- Create: `src/puzzle/remix_job_controller.gd`
- Modify: `src/ui/battle_screen.gd:35-50,54-180,610-625,1058-1067`
- Test: `tests/remix_job_controller_test.gd`
- Test: `tests/remix_job_controller_test.tscn`

**Interfaces:**
- Consumes: immutable board state, seed, difficulty band, capacity.
- Produces: `request(state, seed, band, capacity) -> int`, `poll() -> Dictionary`, `cancel()`, and result keys `ready`, `generation_id`, `result`.

- [ ] **Step 1: Write a failing generation-order test**

```gdscript
extends Node

func _ready() -> void:
	var jobs := RemixJobController.new()
	var state: Array = [["red"],["green"],[],[],[],[]]
	var first := jobs.request(state, 10, "standard", 4)
	var second := jobs.request(state, 11, "standard", 4)
	var result := {}
	while result.is_empty():
		result = jobs.poll()
		await get_tree().process_frame
	var ok := first < second and int(result.generation_id) == second \
			and bool(result.result.analysis.solvable)
	print("PASS  newest generation wins" if ok else "FAIL  stale generation escaped")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Run the new scene. Expected: `RemixJobController` is undefined.

- [ ] **Step 3: Implement the job controller**

```gdscript
class_name RemixJobController
extends RefCounted

var _generation_id := 0
var _task_id := -1

func request(state: Array, seed: int, band: String, capacity: int) -> int:
	_generation_id += 1
	var requested_id := _generation_id
	var copy := state.duplicate(true)
	_task_id = WorkerThreadPool.add_task(func() -> Dictionary:
		return {"generation_id":requested_id,
				"result":BoardFactory.remix(copy, seed, band, capacity)})
	return requested_id

func poll() -> Dictionary:
	if _task_id < 0 or not WorkerThreadPool.is_task_completed(_task_id): return {}
	var payload: Dictionary = WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	if int(payload.get("generation_id", -1)) != _generation_id: return {}
	payload["ready"] = true
	return payload

func cancel() -> void:
	_generation_id += 1
```

In `battle_screen.gd`, create one controller, poll it in `_process`, disable `board` while brewing, apply only the matching result, then call `battle.on_move()` after successful application. On timeout/failure restore the captured snapshot and charge nothing.

- [ ] **Step 4: Verify behavior and latency**

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/remix_job_controller_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/board_factory_test.tscn -- --performance-only
```

Expected: newest generation wins and catalog/remix performance remains under 500 ms for the existing batch test.

- [ ] **Step 5: Commit**

```powershell
git add src/puzzle/remix_job_controller.gd src/ui/battle_screen.gd tests/remix_job_controller_test.*
git commit -m "engine: isolate remix jobs from battle frames"
```

### Task 3: Bounded deterministic replay journal

**Files:**
- Create: `src/run/replay_journal.gd`
- Modify: `src/autoload/run_state.gd:20-55,67-125,196-260`
- Modify: `src/ui/battle_screen.gd:80-180,1028-1067`
- Test: `tests/replay_journal_test.gd`
- Test: `tests/replay_journal_test.tscn`

**Interfaces:**
- Produces: `record(kind, payload)`, `snapshot()`, `restore(data)`, `checksum()`, `clear()`; maximum 300 events.
- `RunState.record_replay(kind, payload)` forwards to one journal and serializes it in boundary version 7.

- [ ] **Step 1: Write the failing journal test**

```gdscript
extends Node

func _ready() -> void:
	var journal := ReplayJournal.new()
	for index in 305: journal.record("move", {"from":index % 6,"to":(index + 1) % 6})
	var snapshot := journal.snapshot()
	var restored := ReplayJournal.new()
	var accepted := restored.restore(snapshot)
	var ok := snapshot.events.size() == 300 and accepted \
			and restored.checksum() == journal.checksum()
	print("PASS  replay bounded and deterministic" if ok else "FAIL  replay contract")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `ReplayJournal` class.

- [ ] **Step 3: Implement the journal**

```gdscript
class_name ReplayJournal
extends RefCounted

const LIMIT := 300
var _events: Array[Dictionary] = []

func record(kind: String, payload := {}) -> void:
	_events.append({"kind":kind, "payload":(payload as Dictionary).duplicate(true)})
	if _events.size() > LIMIT: _events.pop_front()

func checksum() -> int:
	return JSON.stringify(_events).hash()

func snapshot() -> Dictionary:
	return {"version":1, "events":_events.duplicate(true), "checksum":checksum()}

func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or typeof(data.get("events")) != TYPE_ARRAY: return false
	var candidate: Array = data.events.duplicate(true)
	if candidate.size() > LIMIT: return false
	_events.assign(candidate)
	if checksum() != int(data.get("checksum", checksum())):
		_events.clear()
		return false
	return true

func clear() -> void:
	_events.clear()
```

Update RunState boundary version to 7, serialize `replay`, tolerate versions 2-7, and discard only invalid replay data. Record tube moves, undo, accepted remix generation, skill, route, reward, shop, and event selections at their current authoritative handlers.

- [ ] **Step 4: Run replay, lifecycle, and recovery tests**

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/replay_journal_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/run_lifecycle_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/save_recovery_test.tscn
```

Expected: zero failures and legacy boundaries still resume.

- [ ] **Step 5: Commit**

```powershell
git add src/run/replay_journal.gd src/autoload/run_state.gd src/ui/battle_screen.gd tests/replay_journal_test.*
git commit -m "engine: record bounded deterministic run replay"
```

### Task 4: Mobile viewport regression matrix

**Files:**
- Create: `tests/mobile_viewport_matrix_test.gd`
- Create: `tests/mobile_viewport_matrix_test.tscn`
- Modify: `.github/workflows/android-ci.yml:20-28`

**Interfaces:**
- Consumes all primary `.tscn` screens.
- Produces one headless release gate covering three portrait viewport sizes.

- [ ] **Step 1: Write the failing matrix test**

```gdscript
extends Node

const SIZES := [Vector2i(576,1280), Vector2i(720,1280), Vector2i(1080,2400)]
const SCENES := ["main_menu", "area_select", "map", "battle", "event", "shop", "settings"]
var failures := 0

func _ready() -> void:
	for viewport_size in SIZES:
		get_viewport().size = viewport_size
		for scene_name in SCENES:
			var screen := load("res://scenes/%s.tscn" % scene_name).instantiate() as Control
			add_child(screen)
			await get_tree().process_frame
			for node in screen.find_children("*", "Button", true, false):
				if node.visible and (node.size.x < 56 or node.size.y < 56): failures += 1
			screen.queue_free()
	print("PASS  mobile viewport matrix" if failures == 0 else "FAIL  %d bounds" % failures)
	get_tree().quit(1 if failures else 0)
```

- [ ] **Step 2: Run and verify RED**

Expected: current small secondary controls reveal at least one 56-pixel violation.

- [ ] **Step 3: Fix only reported bounds and add CI gate**

Adjust the reported controls through `UiThemeTokens.TOUCH_MIN`, scrolling containers, or safe margins. Add this exact CI command:

```yaml
- name: Mobile viewport matrix
  run: godot --headless --path . res://tests/mobile_viewport_matrix_test.tscn
```

- [ ] **Step 4: Run responsive and viewport tests**

Expected: both `responsive_layout_test.tscn` and `mobile_viewport_matrix_test.tscn` report zero failures.

- [ ] **Step 5: Commit**

```powershell
git add tests/mobile_viewport_matrix_test.* .github/workflows/android-ci.yml src/ui
git commit -m "test: gate portrait viewport compatibility"
```
